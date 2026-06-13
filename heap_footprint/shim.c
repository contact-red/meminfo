#include <pony.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// This shim reads the Pony runtime's own descriptors and drives its per-type
// trace functions. It includes the real <pony.h> (via a `use "cinclude:..."`
// in the Pony source) so pony_type_t matches the runtime build exactly, rather
// than hand-mirroring a layout that a USE_RUNTIME_TRACING build would shift.

// Internal runtime functions. These live in libponyrt --- linked into every
// Pony executable --- but are deliberately absent from the public pony.h, so
// we declare them ourselves. chunk_t stays opaque: we only pass it through.
typedef struct chunk_t chunk_t;
extern chunk_t* ponyint_pagemap_get_chunk(const void* addr);
extern size_t ponyint_heap_size(chunk_t* chunk);

// The allocator slot reserved for the allocation containing addr, or 0 if addr
// is not on a GC heap. The pagemap is global and these reads need no actor
// context, so this is safe to call from any FFI context.
static size_t hf_slot(const void* addr)
{
  if(addr == NULL)
    return 0;

  chunk_t* chunk = ponyint_pagemap_get_chunk(addr);

  if(chunk == NULL)
    return 0;

  return ponyint_heap_size(chunk);
}

// ------------------------------------------------------------------ shallow

// Slot reserved for an object passed by reference. 0 if the object is not
// individually heap-allocated (actors are pool-allocated; embeds, stack values
// and foreign memory are not in the pagemap).
size_t hf_alloc_size(void* p)
{
  return hf_slot(p);
}

// Slot reserved for a raw backing-buffer address (e.g. from String/Array
// cpointer()). 0 if not on a GC heap.
size_t hf_addr_alloc_size(size_t addr)
{
  return hf_slot((const void*)addr);
}

// The logical size the compiler computed for p's type (the descriptor's size
// field). Valid for any object or actor: the first word is always a descriptor
// pointer.
size_t hf_logical_size(void* p)
{
  return (*(pony_type_t**)p)->size;
}

// --------------------------------------------------------------------- deep

// A set of pointers already counted, so shared substructures are counted once
// and cycles terminate. Open addressing with linear probing; NULL marks empty.
typedef struct
{
  void** slots;
  size_t cap;   // always a power of two
  size_t count;
} hf_ptrset_t;

static size_t hf_ptr_hash(void* p)
{
  uintptr_t h = (uintptr_t)p;
  h ^= h >> 33;
  h *= (uintptr_t)0xff51afd7ed558ccdULL;
  h ^= h >> 33;
  return (size_t)h;
}

static void hf_ptrset_init(hf_ptrset_t* s)
{
  s->cap = 1024;
  s->count = 0;
  s->slots = (void**)calloc(s->cap, sizeof(void*));
}

static void hf_ptrset_destroy(hf_ptrset_t* s)
{
  free(s->slots);
  s->slots = NULL;
}

static bool hf_ptrset_add(hf_ptrset_t* s, void* p);

static void hf_ptrset_grow(hf_ptrset_t* s)
{
  size_t oldcap = s->cap;
  void** old = s->slots;

  s->cap = oldcap * 2;
  s->slots = (void**)calloc(s->cap, sizeof(void*));
  s->count = 0;

  for(size_t i = 0; i < oldcap; i++)
    if(old[i] != NULL)
      hf_ptrset_add(s, old[i]);

  free(old);
}

// Returns true if p was newly inserted, false if it was already present.
static bool hf_ptrset_add(hf_ptrset_t* s, void* p)
{
  if((s->count * 4) >= (s->cap * 3)) // grow past a 0.75 load factor
    hf_ptrset_grow(s);

  size_t mask = s->cap - 1;
  size_t i = hf_ptr_hash(p) & mask;

  while(s->slots[i] != NULL)
  {
    if(s->slots[i] == p)
      return false;
    i = (i + 1) & mask;
  }

  s->slots[i] = p;
  s->count++;
  return true;
}

// An object whose trace function still needs to be run to enumerate its
// references. Held on an explicit work stack so a deep or cyclic graph can't
// overflow the C stack.
typedef struct
{
  void* p;
  pony_type_t* t;
} hf_work_t;

// The accumulator. Its leading fields mirror pony_ctx_t up through
// trace_actor, so &hf_deep_t can be passed to the runtime's pony_trace*
// functions as a pony_ctx_t* --- those read only trace_object/trace_actor.
// Our callbacks recover this struct by casting the ctx back.
//
// Layout coupling: pony_ctx_t begins { scheduler, current, trace_object,
// trace_actor, ... } with no build-conditional fields before trace_actor, so
// these offsets are stable. The runtime never reads past trace_actor here
// (we never call its GC mark path), so the trailing accumulator fields are
// invisible to it.
typedef struct hf_deep_t hf_deep_t;
struct hf_deep_t
{
  void* scheduler;
  void* current;
  void (*trace_object)(pony_ctx_t* ctx, void* p, pony_type_t* t, int m);
  void (*trace_actor)(pony_ctx_t* ctx, pony_actor_t* actor);
  void* stack;

  hf_ptrset_t visited;
  hf_work_t* work;
  size_t work_len;
  size_t work_cap;

  size_t object_alloc;
  size_t buffer_alloc;
  size_t object_count;
  size_t buffer_count;
  size_t actor_refs;
};

static void hf_work_push(hf_deep_t* d, void* p, pony_type_t* t)
{
  if(d->work_len == d->work_cap)
  {
    d->work_cap = (d->work_cap == 0) ? 256 : (d->work_cap * 2);
    d->work = (hf_work_t*)realloc(d->work, d->work_cap * sizeof(hf_work_t));
  }

  d->work[d->work_len].p = p;
  d->work[d->work_len].t = t;
  d->work_len++;
}

static void hf_deep_trace_object(pony_ctx_t* ctx, void* p, pony_type_t* t,
  int m)
{
  hf_deep_t* d = (hf_deep_t*)ctx;

  if(p == NULL)
    return;

  if(!hf_ptrset_add(&d->visited, p)) // already counted: dedupe / cycle stop
    return;

  size_t slot = hf_slot(p);

  // Skip anything not on a Pony GC heap: there is nothing to count, and a real
  // Pony object is always heap-allocated, so a zero slot also means "not an
  // object" --- which lets us avoid dereferencing p below when it may point at
  // foreign or static memory.
  if(slot == 0)
    return;

  // Distinguish a real object from a raw backing buffer. The trace site hands
  // us the *static* type t, which is non-NULL even for a buffer (a String's
  // bytes arrive typed as Pointer[U8]). The reliable signal is the pointee's
  // first word: a Pony object stores its own descriptor there, so it equals t;
  // a raw buffer stores data, so it does not. (t == NULL is an opaque trace,
  // always a buffer.)
  bool is_object = (t != NULL) && (*(pony_type_t**)p == t);

  if(is_object)
  {
    d->object_alloc += slot;
    d->object_count++;
  } else {
    d->buffer_alloc += slot;
    d->buffer_count++;
  }

  // Recurse only into real objects, and not through opaque (e.g. tag)
  // references, which the GC marks but does not traverse. Buffers are leaves:
  // a container reaches its elements through its own trace function, not
  // through the buffer.
  if(is_object && (m != PONY_TRACE_OPAQUE) && (t->trace != NULL))
    hf_work_push(d, p, t);
}

static void hf_deep_trace_actor(pony_ctx_t* ctx, pony_actor_t* a)
{
  hf_deep_t* d = (hf_deep_t*)ctx;

  if(a == NULL)
    return;

  // An actor owns its own heap; a reference to it is identity, not owned data.
  // Count distinct referenced actors but never cross the boundary.
  if(hf_ptrset_add(&d->visited, a))
    d->actor_refs++;
}

// Measure the transitive heap footprint of root. Fills a 5-element out array:
//   out[0] object_alloc, out[1] buffer_alloc,
//   out[2] object_count, out[3] buffer_count, out[4] actor_refs.
void hf_deep_measure(void* root, size_t* out)
{
  hf_deep_t d;
  memset(&d, 0, sizeof(d));
  d.trace_object = hf_deep_trace_object;
  d.trace_actor = hf_deep_trace_actor;
  hf_ptrset_init(&d.visited);

  pony_ctx_t* ctx = (pony_ctx_t*)&d;

  if(root != NULL)
  {
    // Seed from the root's actual descriptor, mirroring pony_traceunknown.
    pony_type_t* t = *(pony_type_t**)root;

    if(t->dispatch != NULL)
      hf_deep_trace_actor(ctx, (pony_actor_t*)root);
    else
      hf_deep_trace_object(ctx, root, t, PONY_TRACE_MUTABLE);
  }

  while(d.work_len > 0)
  {
    hf_work_t w = d.work[--d.work_len];
    w.t->trace(ctx, w.p);
  }

  out[0] = d.object_alloc;
  out[1] = d.buffer_alloc;
  out[2] = d.object_count;
  out[3] = d.buffer_count;
  out[4] = d.actor_refs;

  hf_ptrset_destroy(&d.visited);
  free(d.work);
}

// ----------------------------------------------------- whole-actor heap walk

// Minimal mirrors of the runtime's heap structures, to walk an actor's
// allocator lists. heap_t is public (mem/heap.h) but chunk_t is private to
// mem/heap.c, so we mirror only the fields we read.
//
// ABI coupling to src/libponyrt/mem/{heap.h,heap.c}: we need
// chunk_t.small.slots at offset 8 (the free-slot bitmap --- a SET bit is a
// FREE slot) and chunk_t.next at offset 24, plus the constants below
// (HEAP_SIZECLASSES, HEAP_RECYCLE_SIZECLASSES, POOL_ALIGN, HEAP_MIN). If the
// runtime changes any of these, this is the place to fix it.
#define HF_SIZECLASSES 5
#define HF_RECYCLE 4
#define HF_POOL_ALIGN 1024
#define HF_HEAP_MIN 32

typedef struct hf_chunk
{
  void* m;
  union
  {
    struct { uint32_t slots; uint32_t shallow; uint32_t finalisers; } small;
    struct { size_t size; } large;
  } u;
  struct hf_chunk* next;
} hf_chunk;

typedef struct hf_heap
{
  hf_chunk* small_free[HF_SIZECLASSES];
  hf_chunk* small_full[HF_SIZECLASSES];
  hf_chunk* large;
  hf_chunk* recyclable[HF_RECYCLE];
  size_t used;
  size_t next_gc;
} hf_heap;

extern void* ponyint_actor_heap(void* actor);

// Walk the currently-running actor's heap lists and fill a 5-element out array:
//   out[0] in_use bytes, out[1] reserved bytes,
//   out[2] small chunk count, out[3] large chunk count,
//   out[4] small slots in use.
//
// SAFE ONLY for the current actor: these lists mutate as the actor allocates
// and collects. We read pony_ctx()->current, so by construction we measure
// whoever is running --- ourselves --- and GC never runs mid-behaviour.
void hf_actor_self_measure(size_t* out)
{
  out[0] = out[1] = out[2] = out[3] = out[4] = 0;

  // pony_ctx_t begins { scheduler, current, ... }; current is the 2nd pointer.
  void* actor = ((void**)pony_ctx())[1];
  if(actor == NULL)
    return;

  hf_heap* h = (hf_heap*)ponyint_actor_heap(actor);

  size_t in_use = 0, reserved = 0;
  size_t small_chunks = 0, large_chunks = 0, slots_used = 0;

  for(int sc = 0; sc < HF_SIZECLASSES; sc++)
  {
    size_t slot = (size_t)HF_HEAP_MIN << sc;
    size_t total_slots = HF_POOL_ALIGN / slot;

    for(int which = 0; which < 2; which++)
    {
      hf_chunk* c = (which == 0) ? h->small_free[sc] : h->small_full[sc];

      while(c != NULL)
      {
        uint32_t free_slots = (uint32_t)__builtin_popcount(c->u.small.slots);
        if(free_slots > total_slots) // defensive against a transient bitmap
          free_slots = (uint32_t)total_slots;
        size_t used_slots = total_slots - free_slots;

        in_use += used_slots * slot;
        slots_used += used_slots;
        reserved += HF_POOL_ALIGN;
        small_chunks++;
        c = c->next;
      }
    }
  }

  for(hf_chunk* c = h->large; c != NULL; c = c->next)
  {
    size_t sz = ponyint_heap_size((chunk_t*)c);
    in_use += sz;
    reserved += sz;
    large_chunks++;
  }

  out[0] = in_use;
  out[1] = reserved;
  out[2] = small_chunks;
  out[3] = large_chunks;
  out[4] = slots_used;
}
