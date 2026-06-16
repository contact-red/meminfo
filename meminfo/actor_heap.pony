primitive ActorMem
  fun in_use(a: ActorMemType): USize => a._2
  fun reserved(a: ActorMemType): USize => a._3
  fun small_chunks(a: ActorMemType): USize => a._4
  fun large_chunks(a: ActorMemType): USize => a._5
  fun small_slots_used(a: ActorMemType): USize => a._6

  // Total live allocations: small slots in use plus large chunks.
  fun allocations(a: ActorMemType): USize => a._6 + a._5
  // Reserved bytes not currently in use --- size-class slack and partly-filled
  // chunks. Saturates at 0.
  fun overhead(a: ActorMemType): USize =>
    if a._3 >= a._2 then a._3 - a._2 else 0 end

type ActorMemType is (ActorMem, USize, USize, USize, USize, USize)
