use "pony_test"

class \nodoc\ iso _TestFlatStructSize is UnitTest
  fun name(): String => "meminfo/flat/struct_size"

  fun apply(h: TestHelper) =>
    // _TwoWords: descriptor pointer (8) + two U64 fields (16) = 24 logical.
    let mi = MemInfo.flat(_TwoWords)
    h.assert_eq[USize](24, FlatMem.logical(mi))
    h.assert_eq[USize](32, FlatMem.alloc(mi))

    // _ThreeFields: descriptor (8) + three U64 fields (24) = 32 logical.
    let mi2 = MemInfo.flat(_ThreeFields)
    h.assert_eq[USize](32, FlatMem.logical(mi2))
    h.assert_eq[USize](32, FlatMem.alloc(mi2))
    h.assert_true(FlatMem.alloc(mi2) >= FlatMem.logical(mi2))

class \nodoc\ iso _TestFlatActorZeroSlot is UnitTest
  fun name(): String => "meminfo/flat/actor_zero_slot"

  fun apply(h: TestHelper) =>
    let mi = MemInfo.flat(_Dummy)
    h.assert_eq[USize](0, FlatMem.alloc(mi),
      "actors are pool-allocated, not on the GC heap")
    h.assert_true(FlatMem.logical(mi) > 0,
      "descriptor size is still readable")

class \nodoc\ iso _TestFlatAllocGteLogical is UnitTest
  fun name(): String => "meminfo/flat/alloc_gte_logical"

  fun apply(h: TestHelper) =>
    let objs: Array[Any tag] = [_TwoWords; _ThreeFields; String(10); Array[U8]]
    for obj in objs.values() do
      let mi = MemInfo.flat(obj)
      let a = FlatMem.alloc(mi)
      if a > 0 then
        h.assert_true(a >= FlatMem.logical(mi),
          "alloc must >= logical for heap-allocated objects")
      end
    end
