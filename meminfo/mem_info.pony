"""
# meminfo

Measure the amount of heap a Pony object actually occupies, without any
compiler changes.

Every heap-allocated Pony object starts with a pointer to its type descriptor,
and the runtime keeps a global pagemap that maps any heap address back to the
allocator chunk that contains it. From those two facts a small C shim can,
given an object, recover both:

* the **allocator slot** the runtime reserved for it (rounded up to a size
  class --- the real memory footprint), and
* the **logical size** the compiler computed for its type.

Container types (`String`, `Array`) keep their elements in a *separate* heap
allocation reached through their data pointer, so this package follows that
pointer too and reports the backing buffer's footprint alongside the object's.
`deep` goes further, following the whole reference graph (see `DeepMem`).

Each measurement is returned as a tagged tuple --- a marker primitive followed
by the raw figures --- and the marker primitive doubles as the namespace for
reading the fields back out. There is no `Stringable`; read the values you want
through the accessors.

```pony
use "meminfo"

actor Main
  new create(env: Env) =>
    let s: String val = "hello world".clone()

    // Shallow: the String struct plus its one backing byte buffer.
    let m = MemInfo.string(s)
    env.out.print("struct slot: " + StringMem.s_alloc(m).string())
    env.out.print("buffer slot: " + StringMem.p_alloc(m).string())

    // Deep: the whole owned reference graph, each allocation counted once.
    let d = MemInfo.deep(s)
    env.out.print("total allocated: " + DeepMem.allocated(d).string())
```

## Caveats

* The object's allocation slot (`FlatMem.alloc`, `StringMem.s_alloc`,
  `ArrayMem.s_alloc`) is `0` for anything not individually heap-allocated:
  actors (pool-allocated), `embed` fields (part of their parent's allocation),
  stack values, and foreign memory. A `0` slot is the signal for "not a
  distinct heap allocation"; the other figures are not a meaningful footprint
  in that case.
* `flat`/`string`/`array` are *shallow* (object plus, for containers, one
  backing buffer). `deep` follows the whole reference graph --- see `DeepMem`.

The C shim is compiled and linked automatically by `ponyc`; it only needs the
runtime's `pony.h`, which the `cinclude` below points at.
"""

use @mi_alloc_size[USize](o: Any tag)
use @mi_logical_size[USize](o: Any tag)
use @mi_addr_alloc_size[USize](addr: USize)
use @mi_deep_measure[None](root: Any box, out: Pointer[USize] tag)
use @mi_actor_self_measure[None](out: Pointer[USize] tag)


primitive MemInfo
  """
  Measures the heap footprint of an object.

  `flat` works on any object but reports only the object's own allocation.
  `string` and `array` additionally follow the container's backing buffer.
  `deep` follows the whole owned reference graph; `actor_self` walks the
  running actor's entire heap.
  """

  fun flat(obj: Any tag): FlatMemType =>
              // Includes Align    Requested Size
    (FlatMem, @mi_alloc_size(obj), @mi_logical_size(obj))

  fun string(s: String box): StringMemType =>
    """
    Measure a `String`, including its backing byte buffer.
    """
    let p = s.cpointer()
    (StringMem,
      @mi_alloc_size(s),              // String struct allocation
      @mi_logical_size(s),            // String struct size
      @mi_addr_alloc_size(p.usize()), // Pointer obj size allocation
      s.space() + 1,                  // Pointer obj size (String._alloc)
      s.size()                        // String "length"
    )

  fun array[A](a: Array[A] box): ArrayMemType =>
    """
    Measure an `Array`, including its backing element buffer. The buffer's
    in-use bytes are the element count times the element size, which is
    recovered from the spacing between consecutive element addresses.
    """
    let p = a.cpointer()
    let ele_size: USize = a.cpointer(1).usize() - p.usize()
    (ArrayMem,
      @mi_alloc_size(a),                // Array struct allocation
      @mi_logical_size(a),              // Array struct size
      @mi_addr_alloc_size(p.usize()),   // Pointer obj allocation
      a.space(),                        // Number of reserved elements
      a.size(),                         // Element count
      ele_size                          // Element Size
    )

  fun deep(o: Any box): DeepMemType =>
    """
    Measure the transitive heap footprint of `o`: the object itself plus every
    object and backing buffer reachable from it, each distinct allocation
    counted once. Stops at actor references (an actor owns its own heap) and at
    shared substructures and cycles (dedup'd by address).

    Drives the same per-type trace functions the garbage collector uses, so it
    sees exactly what the runtime considers owned and reachable. `o` is taken
    as `box`: the calling actor can read it and everything it owns for the
    duration of this synchronous call.
    """
    let out = Array[USize].init(0, 5)
    @mi_deep_measure(o, out.cpointer())
    (DeepMem,
      try out(0)? else 0 end,   // object_alloc
      try out(1)? else 0 end,   // buffer_alloc
      try out(2)? else 0 end,   // object_count
      try out(3)? else 0 end,   // buffer_count
      try out(4)? else 0 end)   // actor_refs

  fun actor_self(): ActorMemType =>
    """
    Measure the whole heap of the currently-running actor by walking its
    allocator chunk lists. Works on any build --- it needs no runtime-stats
    flag --- and reports both the bytes in use and the bytes reserved from the
    pool.

    Call this from inside one of the actor's own behaviours: it measures
    whoever is running, which is always safe. Another actor's heap mutates
    under its own scheduler thread and must not be walked from outside, so
    there is deliberately no way to point this at a different actor.
    """
    let out = Array[USize].init(0, 5)
    @mi_actor_self_measure(out.cpointer())
    (ActorMem,
      try out(0)? else 0 end,   // in_use
      try out(1)? else 0 end,   // reserved
      try out(2)? else 0 end,   // small_chunks
      try out(3)? else 0 end,   // large_chunks
      try out(4)? else 0 end)   // small_slots_used

