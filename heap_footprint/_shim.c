#include <stddef.h>
#include <stdint.h>

// Layout coupling: this mirrors the head of pony_type_t in
// src/libponyrt/pony.h --- { uint32_t id; uint32_t size; ... }. The type
// descriptor is the first word of every heap-allocated Pony object, so
// *(hf_desc_head_t**)p is the descriptor and ->size is its logical size.
// If the runtime ever reorders id/size, hf_logical_size() breaks here --- this
// is the place to fix it.
typedef struct { uint32_t id; uint32_t size; } hf_desc_head_t;

// Internal runtime functions. These live in libponyrt --- statically linked
// into every Pony executable --- but are deliberately absent from the public
// pony.h header, so we declare them ourselves. chunk_t stays opaque: we only
// pass the pointer through.
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
  hf_desc_head_t* desc = *(hf_desc_head_t**)p;
  return desc->size;
}
