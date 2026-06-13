"""
# heap_footprint

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
`deep` goes further, following the whole reference graph (see `DeepFootprint`).

```pony
use "heap_footprint"

actor Main
  new create(env: Env) =>
    let s: String val = "hello world".clone()
    let shallow = HeapFootprint.string(s) // object + its byte buffer
    env.out.print(shallow.string())
    let deep = HeapFootprint.deep(s)      // the whole owned reference graph
    env.out.print(deep.string())
```

## Caveats

* `object_alloc` is `0` for anything not individually heap-allocated: actors
  (pool-allocated), `embed` fields (part of their parent's allocation), stack
  values, and foreign memory. `object_alloc == 0` is the signal for "not a
  distinct heap allocation"; the other figures are not a meaningful footprint
  in that case.
* `apply`/`string`/`array` are *shallow* (object plus, for containers, one
  backing buffer). `deep` follows the whole reference graph --- see
  `DeepFootprint`.

The C shim is compiled and linked automatically by `ponyc`; it only needs the
runtime's `pony.h`, which the `cinclude` below points at.
"""

// ENVIRONMENT-SPECIFIC: path to the active ponyc install's `include` directory
// (the one holding `pony.h`). Update this for your toolchain --- e.g. for a
// ponyup install it is `<...>/ponyup/<toolchain>/include`.
use "cinclude:/home/red/.local/share/ponyup/ponyc-clang-0.64.0-x86_64-linux-ubuntu24.04/include"

use @hf_alloc_size[USize](o: Any tag)
use @hf_logical_size[USize](o: Any tag)
use @hf_addr_alloc_size[USize](addr: USize)
use @hf_deep_measure[None](root: Any box, out: Pointer[USize] tag)

primitive HeapFootprint
  """
  Measures the heap footprint of an object.

  `apply` works on any object but reports only the object's own allocation.
  `string` and `array` additionally follow the container's backing buffer.
  """
  fun apply(obj: Any tag): Footprint =>
    """
    Measure any object, reporting its own allocation only. Container backing
    buffers are not followed --- use `string` or `array` for those.
    """
    Footprint._create(@hf_alloc_size(obj), @hf_logical_size(obj))

  fun string(s: String box): Footprint =>
    """
    Measure a `String`, including its backing byte buffer.
    """
    let p = s.cpointer()
    let buf_alloc = if p.is_null() then 0 else @hf_addr_alloc_size(p.usize()) end
    Footprint._create(@hf_alloc_size(s), @hf_logical_size(s), buf_alloc, s.size())

  fun array[A](a: Array[A] box): Footprint =>
    """
    Measure an `Array`, including its backing element buffer. The buffer's
    in-use bytes are the element count times the element size, which is
    recovered from the spacing between consecutive element addresses.
    """
    let p = a.cpointer()
    (let buf_alloc: USize, let buf_used: USize) =
      if p.is_null() then
        (USize(0), USize(0))
      else
        let elem_size = a.cpointer(1).usize() - p.usize()
        (@hf_addr_alloc_size(p.usize()), a.size() * elem_size)
      end
    Footprint._create(@hf_alloc_size(a), @hf_logical_size(a), buf_alloc, buf_used)

  fun deep(o: Any box): DeepFootprint =>
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
    @hf_deep_measure(o, out.cpointer())
    DeepFootprint._create(
      try out(0)? else 0 end,
      try out(1)? else 0 end,
      try out(2)? else 0 end,
      try out(3)? else 0 end,
      try out(4)? else 0 end)

class val Footprint is Stringable
  """
  The heap footprint of a single object, optionally including one backing
  buffer. All sizes are in bytes.
  """
  let object_alloc: USize
    """
    The allocator slot reserved for the object itself --- the real heap set
    aside, rounded up to a size class. `0` if the object is not individually
    heap-allocated on a GC heap (actor, `embed` field, stack value, foreign
    memory).
    """

  let object_size: USize
    """
    The logical size the compiler computed for the object's type (its type
    descriptor's `size`). The unrounded struct size.
    """

  let buffer_alloc: USize
    """
    The allocator slot reserved for the object's backing buffer, or `0` if the
    object has no separate buffer.
    """

  let buffer_used: USize
    """
    The bytes of the backing buffer actually in use, or `0` if there is no
    buffer. For a `String` this is its byte length; for an `Array` it is the
    element count times the element size.
    """

  new val _create(object_alloc': USize, object_size': USize,
    buffer_alloc': USize = 0, buffer_used': USize = 0)
  =>
    object_alloc = object_alloc'
    object_size = object_size'
    buffer_alloc = buffer_alloc'
    buffer_used = buffer_used'

  fun allocated(): USize =>
    """
    Total heap reserved for this object: object slot plus backing-buffer slot.
    This is the headline "allocated space in use" figure.
    """
    object_alloc + buffer_alloc

  fun logical(): USize =>
    """
    Total logical size: the object's struct size plus its buffer's in-use
    bytes. Never greater than `allocated()` for a heap-allocated object.
    """
    object_size + buffer_used

  fun overhead(): USize =>
    """
    Bytes reserved but not logically in use --- the cost of size-class rounding
    and spare container capacity. Saturates at `0` (e.g. for a non-heap object
    where `allocated()` is `0`).
    """
    let a = allocated()
    let l = logical()
    if a >= l then a - l else 0 end

  fun string(): String iso^ =>
    recover
      String
        .>append("Footprint(allocated=").>append(allocated().string())
        .>append(" logical=").>append(logical().string())
        .>append(" overhead=").>append(overhead().string())
        .>append(" [object alloc=").>append(object_alloc.string())
        .>append(" size=").>append(object_size.string())
        .>append("; buffer alloc=").>append(buffer_alloc.string())
        .>append(" used=").>append(buffer_used.string())
        .>append("])")
    end

class val DeepFootprint is Stringable
  """
  The transitive heap footprint of an object: every distinct allocation
  reachable from it as owned data, each counted once. All sizes are in bytes.

  The `allocated` total is exact and complete. Per-buffer *utilisation* (used
  vs reserved) is not available at depth --- a buffer is reached as a bare
  pointer, with its owning container's fill count out of reach --- so unlike
  `Footprint`, this type reports only reserved slots.
  """
  let object_alloc: USize
    """Sum of the allocator slots of all descriptor-bearing objects reached."""

  let buffer_alloc: USize
    """Sum of the allocator slots of all backing buffers reached."""

  let object_count: USize
    """Number of distinct descriptor-bearing objects counted."""

  let buffer_count: USize
    """Number of distinct backing buffers counted."""

  let actor_refs: USize
    """
    Number of distinct actors referenced. They are counted but not traversed:
    an actor owns its own heap, so its memory is not part of this footprint.
    """

  new val _create(object_alloc': USize, buffer_alloc': USize,
    object_count': USize, buffer_count': USize, actor_refs': USize)
  =>
    object_alloc = object_alloc'
    buffer_alloc = buffer_alloc'
    object_count = object_count'
    buffer_count = buffer_count'
    actor_refs = actor_refs'

  fun allocated(): USize =>
    """
    Total heap reserved by everything reachable and owned: the exact answer to
    "how much memory does this object hold onto".
    """
    object_alloc + buffer_alloc

  fun count(): USize =>
    """Total number of distinct allocations counted (objects plus buffers)."""
    object_count + buffer_count

  fun string(): String iso^ =>
    recover
      String
        .>append("DeepFootprint(allocated=").>append(allocated().string())
        .>append(" [objects=").>append(object_count.string())
        .>append(" alloc=").>append(object_alloc.string())
        .>append("; buffers=").>append(buffer_count.string())
        .>append(" alloc=").>append(buffer_alloc.string())
        .>append("; actor_refs=").>append(actor_refs.string())
        .>append("])")
    end
