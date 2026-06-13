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

    // Deep (transitive) mode.
    test(_TestDeepStringMatchesShallow)
    test(_TestDeepNestedSum)
    test(_TestDeepSharingDeduped)
    test(_TestDeepCycleTerminates)
    test(_TestDeepActorBoundary)
    test(Property1UnitTest[USize](_DeepArrayOfStringsProperty))

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

// ----------------------------------------------------------------- deep mode

class \nodoc\ _Pair
  """
  A small object graph with no sharing: an object owning a String and an
  Array, each with its own backing buffer.
  """
  let label: String val
  let nums: Array[U64]
  new create() =>
    label = "hello-world-foo".clone()
    nums = [as U64: 1; 2; 3; 4; 5]

class \nodoc\ _Cycle
  var next: (_Cycle | None) = None
  let payload: String val = "cycle-payload".clone()

actor \nodoc\ _DeepDummyActor
  be noop() => None

class \nodoc\ _HoldsActor
  let who: _DeepDummyActor
  let label: String val
  new create(o: _DeepDummyActor) =>
    who = o
    label = "the-label".clone()

class \nodoc\ iso _TestDeepStringMatchesShallow is UnitTest
  fun name(): String => "heap_footprint/deep/string_matches_shallow"

  fun apply(h: TestHelper) =>
    let s: String val = "hello world".clone()
    let deep = HeapFootprint.deep(s)
    // A String is one object plus one backing buffer; deep must agree with the
    // shallow string measurement's total.
    h.assert_eq[USize](HeapFootprint.string(s).allocated(), deep.allocated())
    h.assert_eq[USize](1, deep.object_count)
    h.assert_eq[USize](1, deep.buffer_count)
    h.assert_eq[USize](0, deep.actor_refs)

class \nodoc\ iso _TestDeepNestedSum is UnitTest
  fun name(): String => "heap_footprint/deep/nested_sum"

  fun apply(h: TestHelper) =>
    let p = _Pair
    let deep = HeapFootprint.deep(p)
    // Cross-check the transitive total against the sum of the shallow slots of
    // each distinct component (no sharing in _Pair).
    let expect =
      HeapFootprint(p).object_alloc
        + HeapFootprint.string(p.label).allocated()
        + HeapFootprint.array[U64](p.nums).allocated()
    h.assert_eq[USize](expect, deep.allocated())
    // 3 objects: the pair, the string, the array.
    h.assert_eq[USize](3, deep.object_count)
    // 2 buffers: the string's bytes, the array's elements.
    h.assert_eq[USize](2, deep.buffer_count)

class \nodoc\ iso _TestDeepSharingDeduped is UnitTest
  fun name(): String => "heap_footprint/deep/sharing_deduped"

  fun apply(h: TestHelper) =>
    // The same String object referenced four times must be counted once.
    let s: String val = "shared-value".clone()
    let arr = [s; s; s; s]
    let deep = HeapFootprint.deep(arr)
    h.assert_eq[USize](2, deep.object_count) // the array + one shared string
    let expect =
      HeapFootprint.array[String](arr).allocated()
        + HeapFootprint.string(s).allocated()
    h.assert_eq[USize](expect, deep.allocated())

class \nodoc\ iso _TestDeepCycleTerminates is UnitTest
  fun name(): String => "heap_footprint/deep/cycle_terminates"

  fun apply(h: TestHelper) =>
    // A self-referential structure must terminate and count each node once.
    let a: _Cycle ref = _Cycle
    a.next = a
    let deep = HeapFootprint.deep(a)
    h.assert_eq[USize](2, deep.object_count) // the node + its payload string
    h.assert_eq[USize](1, deep.buffer_count)
    h.assert_true(deep.allocated() > 0)

class \nodoc\ iso _TestDeepActorBoundary is UnitTest
  fun name(): String => "heap_footprint/deep/actor_boundary"

  fun apply(h: TestHelper) =>
    let obj: _HoldsActor ref = _HoldsActor(_DeepDummyActor)
    let deep = HeapFootprint.deep(obj)
    // The actor is referenced but not traversed.
    h.assert_eq[USize](1, deep.actor_refs)
    h.assert_eq[USize](2, deep.object_count) // the holder + its label string
    h.assert_eq[USize](1, deep.buffer_count)
    // The actor's heap is excluded: total is just the owned data.
    let expect =
      HeapFootprint(obj).object_alloc
        + HeapFootprint.string(obj.label).allocated()
    h.assert_eq[USize](expect, deep.allocated())

class \nodoc\ iso _DeepArrayOfStringsProperty is Property1[USize]
  """
  An Array of n distinct non-empty strings has n+1 objects (array + strings)
  and n+1 buffers (the array's pointer storage + each string's bytes), and its
  transitive total equals the summed shallow slots of its parts.
  """
  fun name(): String => "heap_footprint/deep/property/array_of_strings"

  fun gen(): Generator[USize] =>
    Generators.usize(1, 30)

  fun ref property(n: USize, ph: PropertyHelper) =>
    let arr = Array[String](n)
    var i: USize = 0
    while i < n do
      arr.push("element".clone()) // each clone is a distinct object
      i = i + 1
    end
    let deep = HeapFootprint.deep(arr)
    ph.assert_eq[USize](n + 1, deep.object_count)
    ph.assert_eq[USize](n + 1, deep.buffer_count)

    var expect = HeapFootprint.array[String](arr).allocated()
    for s in arr.values() do
      expect = expect + HeapFootprint.string(s).allocated()
    end
    ph.assert_eq[USize](expect, deep.allocated())
