class val ActorHeap is Stringable
  """
  A snapshot of the currently-running actor's whole heap, taken by walking its
  allocator chunk lists. All sizes are in bytes. The free-chunk recycle cache
  is not included.
  """
  let in_use: USize
    """Live bytes in use: occupied small-area slots plus large allocations."""

  let reserved: USize
    """
    Pool memory backing the actor's active chunks: a full block per small chunk
    plus each large allocation. Always `>= in_use`.
    """

  let small_chunks: USize
    """Number of small-area chunks (1 KB blocks) the actor holds."""

  let large_chunks: USize
    """Number of large (> 512 byte) allocations."""

  let small_slots_used: USize
    """Number of occupied slots in the small area (small live allocations)."""

  new val _create(in_use': USize, reserved': USize, small_chunks': USize,
    large_chunks': USize, small_slots_used': USize)
  =>
    in_use = in_use'
    reserved = reserved'
    small_chunks = small_chunks'
    large_chunks = large_chunks'
    small_slots_used = small_slots_used'

  fun allocations(): USize =>
    """Total live allocations: small slots in use plus large chunks."""
    small_slots_used + large_chunks

  fun overhead(): USize =>
    """
    Reserved bytes not currently in use --- size-class slack and partly-filled
    chunks. Saturates at `0`.
    """
    if reserved >= in_use then reserved - in_use else 0 end

  fun string(): String iso^ =>
    recover
      String
        .>append("ActorHeap(in_use=").>append(in_use.string())
        .>append(" reserved=").>append(reserved.string())
        .>append(" overhead=").>append(overhead().string())
        .>append(" [small_chunks=").>append(small_chunks.string())
        .>append(" slots=").>append(small_slots_used.string())
        .>append("; large_chunks=").>append(large_chunks.string())
        .>append("])")
    end
