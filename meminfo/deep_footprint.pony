primitive DeepMem
  fun object_alloc(a: DeepMemType): USize => a._2
  fun buffer_alloc(a: DeepMemType): USize => a._3
  fun object_count(a: DeepMemType): USize => a._4
  fun buffer_count(a: DeepMemType): USize => a._5
  fun actor_refs(a: DeepMemType): USize => a._6

  // Total heap reserved by everything reachable and owned.
  fun allocated(a: DeepMemType): USize => a._2 + a._3
  // Total number of distinct allocations counted (objects plus buffers).
  fun count(a: DeepMemType): USize => a._4 + a._5

type DeepMemType is (DeepMem, USize, USize, USize, USize, USize)
