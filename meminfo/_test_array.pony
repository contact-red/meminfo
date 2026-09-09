use "pony_test"
use "pony_check"

class \nodoc\ iso _TestArrayEmpty is UnitTest
  fun name(): String => "meminfo/array/empty"

  fun apply(h: TestHelper) =>
    let mi = MemInfo.array[U64](Array[U64])
    h.assert_eq[USize](0, ArrayMem.p_alloc(mi))
    h.assert_eq[USize](0, ArrayMem.a_reserved(mi))
    h.assert_eq[USize](0, ArrayMem.a_count(mi))
    h.assert_eq[USize](8, ArrayMem.e_size(mi))

    let mi2 = MemInfo.array[U8](Array[U8])
    h.assert_eq[USize](0, ArrayMem.p_alloc(mi2))
    h.assert_eq[USize](0, ArrayMem.a_reserved(mi2))
    h.assert_eq[USize](0, ArrayMem.a_count(mi2))
    h.assert_eq[USize](1, ArrayMem.e_size(mi2))

    let mi3 = MemInfo.array[String](Array[String])
    h.assert_eq[USize](0, ArrayMem.p_alloc(mi3))
    h.assert_eq[USize](0, ArrayMem.a_reserved(mi3))
    h.assert_eq[USize](0, ArrayMem.a_count(mi3))
    h.assert_eq[USize](8, ArrayMem.e_size(mi3),
      "pointer-sized elements for boxed types")

class \nodoc\ iso _TestArrayElementSize is UnitTest
  fun name(): String => "meminfo/array/element_size"

  fun apply(h: TestHelper) =>
    let ami = MemInfo.array[U64]([as U64: 1; 2; 3])
    h.assert_eq[USize](64, ArrayMem.p_alloc(ami))
    h.assert_eq[USize](8, ArrayMem.a_reserved(ami))
    h.assert_eq[USize](3, ArrayMem.a_count(ami))
    h.assert_eq[USize](8, ArrayMem.e_size(ami))
    h.assert_eq[USize](24, ArrayMem.a_count(ami) * ArrayMem.e_size(ami))

    let bmi = MemInfo.array[U64](
      [as U64: 1; 2; 3; 4; 5; 6; 7; 8; 9; 10])
    h.assert_eq[USize](128, ArrayMem.p_alloc(bmi))
    h.assert_eq[USize](16, ArrayMem.a_reserved(bmi))
    h.assert_eq[USize](10, ArrayMem.a_count(bmi))
    h.assert_eq[USize](8, ArrayMem.e_size(bmi))
    h.assert_eq[USize](80, ArrayMem.a_count(bmi) * ArrayMem.e_size(bmi))

    let cmi = MemInfo.array[U16](
      [as U16: 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11])
    h.assert_eq[USize](32, ArrayMem.p_alloc(cmi))
    h.assert_eq[USize](16, ArrayMem.a_reserved(cmi))
    h.assert_eq[USize](11, ArrayMem.a_count(cmi))
    h.assert_eq[USize](2, ArrayMem.e_size(cmi))
    h.assert_eq[USize](22, ArrayMem.a_count(cmi) * ArrayMem.e_size(cmi))

class \nodoc\ iso _ArrayU8FootprintProperty is Property1[USize]
  fun name(): String => "meminfo/array/property/u8_footprint"

  fun gen(): Generator[USize] =>
    _SizeClassBiasedLen.gen()

  fun ref property(n: USize, ph: PropertyHelper) =>
    let a = Array[U8](n)
    var i: USize = 0
    while i < n do
      a.push(i.u8())
      i = i + 1
    end
    let mi = MemInfo.array[U8](a)
    ph.assert_eq[USize](n, ArrayMem.a_count(mi))
    ph.assert_eq[USize](a.space(), ArrayMem.a_reserved(mi))
    ph.assert_eq[USize](1, ArrayMem.e_size(mi))
    ph.assert_true(ArrayMem.s_alloc(mi) >= ArrayMem.s_logical(mi),
      "struct slot must fit the struct")
    if n > 0 then
      ph.assert_true(ArrayMem.p_alloc(mi) > 0,
        "non-empty array must have a buffer allocation")
      ph.assert_true(
        ArrayMem.p_alloc(mi) >= (ArrayMem.a_reserved(mi) * ArrayMem.e_size(mi)),
        "buffer slot must fit reserved elements")
    end

class \nodoc\ iso _ArrayU64FootprintProperty is Property1[USize]
  fun name(): String => "meminfo/array/property/u64_footprint"

  fun gen(): Generator[USize] =>
    // Scale down: each U64 element is 8 bytes, so 75 elements is 600 bytes —
    // same byte range as the U8 property.
    Generators.frequency[USize]([
      as WeightedGenerator[USize]:
      (6, Generators.usize(0, 75))
      (1, Generators.one_of[USize](
        [USize(0); 1; 3; 4; 5; 7; 8; 9; 15; 16; 17; 31; 32; 33; 64]))
    ])

  fun ref property(n: USize, ph: PropertyHelper) =>
    let a = Array[U64](n)
    var i: USize = 0
    while i < n do
      a.push(i.u64())
      i = i + 1
    end
    let mi = MemInfo.array[U64](a)
    ph.assert_eq[USize](n, ArrayMem.a_count(mi))
    ph.assert_eq[USize](a.space(), ArrayMem.a_reserved(mi))
    ph.assert_eq[USize](8, ArrayMem.e_size(mi))
    ph.assert_true(ArrayMem.s_alloc(mi) >= ArrayMem.s_logical(mi))
    if n > 0 then
      ph.assert_true(ArrayMem.p_alloc(mi) > 0)
      ph.assert_true(
        ArrayMem.p_alloc(mi) >= (ArrayMem.a_reserved(mi) * ArrayMem.e_size(mi)))
    end

class \nodoc\ iso _ArrayStringFootprintProperty is Property1[USize]
  fun name(): String => "meminfo/array/property/string_footprint"

  fun gen(): Generator[USize] =>
    Generators.frequency[USize]([
      as WeightedGenerator[USize]:
      (6, Generators.usize(0, 75))
      (1, Generators.one_of[USize](
        [USize(0); 1; 3; 4; 5; 7; 8; 9; 15; 16; 17]))
    ])

  fun ref property(n: USize, ph: PropertyHelper) =>
    let a = Array[String](n)
    var i: USize = 0
    while i < n do
      a.push("element")
      i = i + 1
    end
    let mi = MemInfo.array[String](a)
    ph.assert_eq[USize](n, ArrayMem.a_count(mi))
    ph.assert_eq[USize](a.space(), ArrayMem.a_reserved(mi))
    ph.assert_eq[USize](8, ArrayMem.e_size(mi),
      "boxed types are pointer-sized")
    ph.assert_true(ArrayMem.s_alloc(mi) >= ArrayMem.s_logical(mi))
    if n > 0 then
      ph.assert_true(ArrayMem.p_alloc(mi) > 0)
      ph.assert_true(
        ArrayMem.p_alloc(mi) >= (ArrayMem.a_reserved(mi) * ArrayMem.e_size(mi)))
    end

class \nodoc\ iso _ArrayElementSizeInvariantProperty is Property1[USize]
  fun name(): String => "meminfo/array/property/element_size_invariant"

  fun gen(): Generator[USize] =>
    Generators.usize(1, 50)

  fun ref property(n: USize, ph: PropertyHelper) =>
    // Two arrays of different sizes must report the same e_size.
    let a = Array[U64](n)
    var i: USize = 0
    while i < n do
      a.push(i.u64())
      i = i + 1
    end
    let b = Array[U64](n + 10)
    i = 0
    while i < (n + 10) do
      b.push(i.u64())
      i = i + 1
    end
    let ma = MemInfo.array[U64](a)
    let mb = MemInfo.array[U64](b)
    ph.assert_eq[USize](ArrayMem.e_size(ma), ArrayMem.e_size(mb),
      "e_size must be constant for a given element type")
