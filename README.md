# heap_footprint

Measure how much heap a Pony object actually occupies — no compiler changes
required.

Every heap-allocated Pony object begins with a pointer to its type descriptor,
and the runtime keeps a global *pagemap* that maps any heap address back to the
allocator chunk containing it. A small C shim uses those two facts to recover,
for any object:

- the **allocator slot** the runtime reserved for it (rounded up to a size
  class — the real memory footprint), and
- the **logical size** the compiler computed for its type.

It comes in two modes:

- **Shallow** (`apply`, `string`, `array`) — the object itself, plus, for
  containers, its one backing buffer.
- **Deep** (`deep`) — the whole reference graph: the object and every object
  and buffer transitively reachable as owned data, each distinct allocation
  counted once.
- **Whole-actor** (`actor_self`) — the running actor's entire heap, by walking
  its allocator chunk lists; no runtime-stats build required.

## Building

The shim (`heap_footprint/shim.c`) is compiled and linked automatically by
`ponyc` — there is no library to build. It only needs the runtime's `pony.h`,
which it reaches through the `use "cinclude:..."` line near the top of
`heap_footprint/heap_footprint.pony`.

**That path is environment-specific** (it points into your ponyc install) and
must be updated for your toolchain. Find the right value with:

```sh
echo "$(dirname "$(dirname "$(readlink -f "$(which ponyc)")")")/include"
```

Run the tests with:

```sh
make test          # or: ponyc heap_footprint -b heap_footprint_test && ./heap_footprint/heap_footprint_test
```

## Usage

```pony
use "heap_footprint"

actor Main
  new create(env: Env) =>
    let s: String val = "hello world".clone()

    // Shallow: object + its one backing buffer.
    env.out.print(HeapFootprint.string(s).string())
    // Footprint(allocated=64 logical=43 overhead=21
    //   [object alloc=32 size=32; buffer alloc=32 used=11])

    // Deep: the whole owned reference graph.
    env.out.print(HeapFootprint.deep(s).string())
    // DeepFootprint(allocated=64 [objects=1 alloc=32; buffers=1 alloc=32; actor_refs=0])
```

### API

`HeapFootprint`:

- `apply(obj: Any tag): Footprint` — shallow: the object's own allocation.
- `string(s: String box): Footprint` — shallow: a `String` plus its byte buffer.
- `array[A](a: Array[A] box): Footprint` — shallow: an `Array` plus its element
  buffer.
- `deep(o: Any box): DeepFootprint` — transitive: everything reachable and
  owned.

`Footprint` (shallow; all sizes in bytes):

- `object_alloc` / `object_size` — the object's slot, and its logical struct
  size.
- `buffer_alloc` / `buffer_used` — the backing buffer's slot, and the bytes in
  use (`0` if none).
- `allocated()` = `object_alloc + buffer_alloc`; `logical()` =
  `object_size + buffer_used`; `overhead()` = the difference, saturating at `0`.

`DeepFootprint` (transitive; all sizes in bytes):

- `object_alloc` / `object_count` — summed slots and number of distinct
  descriptor-bearing objects.
- `buffer_alloc` / `buffer_count` — summed slots and number of distinct backing
  buffers.
- `actor_refs` — number of distinct actors referenced (counted, not traversed).
- `allocated()` = `object_alloc + buffer_alloc`; `count()` =
  `object_count + buffer_count`.

`HeapFootprint.actor_self(): ActorHeap` — the running actor's whole heap (all
sizes in bytes):

- `in_use` — live bytes: occupied small-area slots plus large allocations.
- `reserved` — pool memory backing active chunks (a full block per small chunk
  plus each large allocation); always `>= in_use`.
- `small_chunks` / `large_chunks` — chunk counts.
- `small_slots_used` — occupied small-area slots; `allocations()` adds the large
  chunks; `overhead()` = `reserved - in_use`.

```pony
// inside any behaviour of the actor you want to measure:
env.out.print(HeapFootprint.actor_self().string())
// ActorHeap(in_use=8224 reserved=10240 overhead=2016
//   [small_chunks=8 slots=105; large_chunks=1])
```

## Semantics and caveats

- **Shallow `object_alloc` is `0`** for anything not individually
  heap-allocated: actors (pool-allocated), `embed` fields (folded into their
  parent), stack values, and foreign memory. Treat `object_alloc == 0` as "not
  a distinct heap allocation".
- **Deep stops at actor boundaries.** An actor owns its own heap, so a
  reference to one is counted in `actor_refs` but never traversed — its memory
  is not part of this object's footprint.
- **Deep dedups by address**, so shared `val` substructures are counted once
  and cycles terminate. It drives the same per-type trace functions the garbage
  collector uses, so it sees exactly what the runtime considers owned and
  reachable.
- **Deep `allocated` is exact and complete**, but it does not report per-buffer
  *utilisation* (used vs reserved): a buffer is reached as a bare pointer with
  its owning container's fill count out of reach. Use shallow `string`/`array`
  when you need `buffer_used`.
- **`actor_self` measures only the current actor.** It reads
  `pony_ctx()->current` and walks that actor's chunk lists, so by construction
  you can only measure whoever is running — call it from inside the actor's own
  behaviours. Another actor's lists mutate under its scheduler thread and must
  not be walked from outside; there is deliberately no API to point it
  elsewhere. (GC never runs mid-behaviour, so the snapshot is consistent.)
- **`actor_self` couples to the allocator layout.** Unlike the rest of the
  package, it mirrors private `chunk_t`/`heap_t` layout (`heap.c`/`heap.h`) and
  the `POOL_ALIGN`/size-class constants. If a future runtime changes those, the
  ABI comment in `shim.c` marks where to fix it.

## How it works

The shim (`heap_footprint/shim.c`) calls two internal runtime functions —
`ponyint_pagemap_get_chunk` and `ponyint_heap_size` — present in `libponyrt`
(linked into every Pony executable) but absent from the public `pony.h`. For
deep mode it builds a private trace context whose `trace_object`/`trace_actor`
callbacks accumulate footprint, then runs each object's existing trace
function — the same machinery the GC uses to walk references. The pagemap is
global and these reads need no actor context, so they are safe from any FFI
context.
