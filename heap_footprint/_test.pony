use "pony_test"
use "pony_check"

actor \nodoc\ Main is TestList
  new create(env: Env) => PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    // Example-based: exact, layout-derived facts.
    test(_TestObjectStructSize)
    test(_TestActorNotOnHeap)
    test(_TestEmptyArray)
    test(_TestStringBufferExact)
    test(_TestArrayElementSize)
    test(_TestDerivedArithmetic)

    // Property-based: relationships that must hold across all sizes.
    test(Property1UnitTest[String](_StringFootprintProperty))
    test(Property1UnitTest[USize](_ArrayU8FootprintProperty))
    test(Property1UnitTest[USize](_ArrayU64FootprintProperty))

class \nodoc\ _TwoWords
  """A class whose struct size we can compute by hand."""
  var a: U64 = 0
  var b: U64 = 0

actor \nodoc\ _Dummy
  be noop() => None

class \nodoc\ iso _TestObjectStructSize is UnitTest
  fun name(): String => "heap_footprint/object/struct_size"

  fun apply(h: TestHelper) =>
    let f = HeapFootprint(_TwoWords)
    // descriptor pointer (8) + two U64 fields (16).
    h.assert_eq[USize](24, f.object_size)
    // rounds up to the 32-byte minimum size class.
    h.assert_eq[USize](32, f.object_alloc)
    h.assert_eq[USize](0, f.buffer_alloc)
    h.assert_eq[USize](0, f.buffer_used)
    h.assert_true(f.object_alloc >= f.object_size)

class \nodoc\ iso _TestActorNotOnHeap is UnitTest
  fun name(): String => "heap_footprint/object/actor_not_on_heap"

  fun apply(h: TestHelper) =>
    let f = HeapFootprint(_Dummy)
    // Actors are pool-allocated, not on a GC heap.
    h.assert_eq[USize](0, f.object_alloc)
    // But the descriptor size is still readable.
    h.assert_true(f.object_size > 0)
    h.assert_eq[USize](0, f.allocated())
    // overhead must saturate rather than underflow.
    h.assert_eq[USize](0, f.overhead())

class \nodoc\ iso _TestEmptyArray is UnitTest
  fun name(): String => "heap_footprint/array/empty"

  fun apply(h: TestHelper) =>
    let f = HeapFootprint.array[U64](Array[U64])
    h.assert_eq[USize](0, f.buffer_alloc)
    h.assert_eq[USize](0, f.buffer_used)
    h.assert_true(f.object_alloc > 0)

class \nodoc\ iso _TestStringBufferExact is UnitTest
  fun name(): String => "heap_footprint/string/buffer_exact"

  fun apply(h: TestHelper) =>
    let s: String val = "hello world".clone() // 11 heap bytes of content
    let f = HeapFootprint.string(s)
    h.assert_eq[USize](11, f.buffer_used)
    // Buffer holds the content plus a null terminator.
    h.assert_true(f.buffer_alloc >= 12)
    h.assert_true(f.buffer_alloc >= f.buffer_used)
    // String struct: descriptor + _size + _alloc + _ptr.
    h.assert_eq[USize](32, f.object_size)
    h.assert_eq[USize](32, f.object_alloc)

class \nodoc\ iso _TestArrayElementSize is UnitTest
  fun name(): String => "heap_footprint/array/element_size"

  fun apply(h: TestHelper) =>
    // U64 elements: 8 bytes each.
    let a64 = [as U64: 1; 2; 3]
    let f64 = HeapFootprint.array[U64](a64)
    h.assert_eq[USize](24, f64.buffer_used)
    h.assert_true(f64.buffer_alloc >= 24)

    // U16 elements: 2 bytes each.
    let a16 = [as U16: 1; 2; 3; 4; 5]
    let f16 = HeapFootprint.array[U16](a16)
    h.assert_eq[USize](10, f16.buffer_used)
    h.assert_true(f16.buffer_alloc >= 10)

class \nodoc\ iso _TestDerivedArithmetic is UnitTest
  fun name(): String => "heap_footprint/derived/arithmetic"

  fun apply(h: TestHelper) =>
    let a = Array[U8](10)
    a.push(1); a.push(2)
    let f = HeapFootprint.array[U8](a)
    h.assert_eq[USize](f.object_alloc + f.buffer_alloc, f.allocated())
    h.assert_eq[USize](f.object_size + f.buffer_used, f.logical())
    h.assert_true(f.allocated() >= f.logical())
    h.assert_eq[USize](f.allocated() - f.logical(), f.overhead())

class \nodoc\ iso _StringFootprintProperty is Property1[String]
  """For any string, the buffer's in-use bytes equal its byte length."""
  fun name(): String => "heap_footprint/property/string"

  fun gen(): Generator[String] =>
    Generators.byte_string(Generators.u8(), 0, 200)

  fun ref property(s: String, ph: PropertyHelper) =>
    let f = HeapFootprint.string(s)
    ph.assert_eq[USize](s.size(), f.buffer_used)
    ph.assert_true(f.buffer_alloc >= f.buffer_used)
    ph.assert_true(f.object_alloc >= f.object_size)
    ph.assert_true(f.allocated() >= f.logical())

class \nodoc\ iso _ArrayU8FootprintProperty is Property1[USize]
  """For an Array[U8] of length n, the buffer holds exactly n bytes."""
  fun name(): String => "heap_footprint/property/array_u8"

  fun gen(): Generator[USize] =>
    Generators.usize(0, 500)

  fun ref property(n: USize, ph: PropertyHelper) =>
    let a = Array[U8](n)
    var i: USize = 0
    while i < n do
      a.push(i.u8())
      i = i + 1
    end
    let f = HeapFootprint.array[U8](a)
    ph.assert_eq[USize](n, f.buffer_used)
    ph.assert_true(f.buffer_alloc >= f.buffer_used)
    ph.assert_true(f.allocated() >= f.logical())
    if n > 0 then
      ph.assert_true(f.buffer_alloc > 0)
    end

class \nodoc\ iso _ArrayU64FootprintProperty is Property1[USize]
  """For an Array[U64] of length n, the buffer holds exactly n*8 bytes."""
  fun name(): String => "heap_footprint/property/array_u64"

  fun gen(): Generator[USize] =>
    Generators.usize(0, 200)

  fun ref property(n: USize, ph: PropertyHelper) =>
    let a = Array[U64](n)
    var i: USize = 0
    while i < n do
      a.push(i.u64())
      i = i + 1
    end
    let f = HeapFootprint.array[U64](a)
    ph.assert_eq[USize](n * 8, f.buffer_used)
    ph.assert_true(f.buffer_alloc >= f.buffer_used)
    if n > 0 then
      ph.assert_true(f.buffer_alloc > 0)
    end
