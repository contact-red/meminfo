# heap_footprint

Measure how much heap a Pony object actually occupies — no compiler changes
required.

Every heap-allocated Pony object begins with a pointer to its type descriptor,
and the runtime keeps a global *pagemap* that maps any heap address back to the
allocator chunk containing it. A ~40-line C shim uses those two facts to
recover, for any object:

- the **allocator slot** the runtime reserved for it (rounded up to a size
  class — the real memory footprint), and
- the **logical size** the compiler computed for its type.

Container types (`String`, `Array`) store their elements in a *separate* heap
allocation reached through their data pointer, so this package follows that
pointer too and reports the backing buffer's footprint alongside the object.

## Building

The C shim must be compiled into a static library before you compile anything
that uses the package:

```sh
make
```

This produces `heap_footprint/lib/libheap_footprint.a`. The package links it
with `use "lib:heap_footprint"` + `use "path:lib"`; because relative `path:`
locators resolve against the package directory, consumers link it
automatically no matter where they compile from.

Run the tests with:

```sh
make test
```

## Usage

```pony
use "heap_footprint"

actor Main
  new create(env: Env) =>
    let s = "hello world".clone()
    let f = HeapFootprint.string(s)

    env.out.print(f.string())
    // Footprint(allocated=64 logical=43 overhead=21
    //   [object alloc=32 size=32; buffer alloc=32 used=11])

    env.out.print("allocated " + f.allocated().string() + " bytes")
```

### API

`HeapFootprint`:

- `apply(obj: Any tag): Footprint` — measure any object's own allocation.
- `string(s: String box): Footprint` — measure a `String` plus its byte buffer.
- `array[A](a: Array[A] box): Footprint` — measure an `Array` plus its element
  buffer.

`Footprint` (all sizes in bytes):

- `object_alloc` — allocator slot for the object itself (`0` if not on a GC
  heap).
- `object_size` — the compiler's logical struct size.
- `buffer_alloc` — allocator slot for the backing buffer (`0` if none).
- `buffer_used` — backing-buffer bytes actually in use (`0` if none).
- `allocated()` — `object_alloc + buffer_alloc`; the headline figure.
- `logical()` — `object_size + buffer_used`.
- `overhead()` — `allocated() - logical()`, saturating at `0`.

## Caveats

- `object_alloc` is `0` for anything not individually heap-allocated: actors
  (pool-allocated), `embed` fields (folded into their parent's allocation),
  stack values, and foreign memory. Treat `object_alloc == 0` as "not a
  distinct heap allocation" — the other figures are not a meaningful footprint
  in that case.
- Measurement is shallow plus one container buffer. It does **not** recurse
  into the objects a field references. A future "deep" mode would walk the
  reference graph via each type's trace function, summing the slot of every
  distinct heap pointer and skipping embeds.

## How it works

The shim (`heap_footprint/_shim.c`) calls two internal runtime functions —
`ponyint_pagemap_get_chunk` and `ponyint_heap_size` — which are present in
`libponyrt` (statically linked into every Pony executable) but absent from the
public `pony.h`. This is the same FFI-into-the-runtime pattern the stdlib
`time`, `net`, and `process` packages already use. The pagemap is global and
these reads need no actor context, so they are safe from any FFI context.
