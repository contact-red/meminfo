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
