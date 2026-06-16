use "pony_test"
use "pony_check"

actor \nodoc\ Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    // Example-based: exact, layout-derived facts.
    test(_TestObjectStructSize)
//    test(_TestActorNotOnHeap)
    test(_TestEmptyArray)
    test(_TestStringBufferExact)
    test(_TestArrayElementSize)
//    test(_TestDerivedArithmetic)

    // Property-based: relationships that must hold across all sizes.
    test(Property1UnitTest[String](_StringFootprintProperty))
//    test(Property1UnitTest[USize](_ArrayU8FootprintProperty))
//    test(Property1UnitTest[USize](_ArrayU64FootprintProperty))

    // Deep (transitive) mode.
    test(_TestDeepStringMatchesShallow)
    test(_TestDeepNestedSum)
    test(_TestDeepSharingDeduped)
    test(_TestDeepCycleTerminates)
    test(_TestDeepActorBoundary)
    test(Property1UnitTest[USize](_DeepArrayOfStringsProperty))

    // Whole-actor heap walk.
    test(_TestActorHeapLargeDelta)
    test(_TestActorHeapSmallDelta)

class \nodoc\ _TwoWords
  """A class whose struct size we can compute by hand."""
  var a: U64 = 0
  var b: U64 = 0

actor \nodoc\ _Dummy
  be noop() => None

class \nodoc\ iso _TestObjectStructSize is UnitTest
  fun name(): String => "meminfo/object/struct_size"

  fun apply(h: TestHelper) =>
    let mi: FlatMemType = MemInfo.flat(_TwoWords)
    // descriptor pointer (8) + two U64 fields (16).
    h.assert_eq[USize](24, FlatMem.logical(mi))
    // rounds up to the 32-byte minimum size class.
    h.assert_eq[USize](32, FlatMem.alloc(mi))
/*
class \nodoc\ iso _TestActorNotOnHeap is UnitTest
  fun name(): String => "meminfo/object/actor_not_on_heap"

  fun apply(h: TestHelper) =>
    let f = MemInfo(_Dummy)
    // Actors are pool-allocated, not on a GC heap.
    h.assert_eq[USize](0, f.object_alloc)
    // But the descriptor size is still readable.
    h.assert_true(f.object_size > 0)
    h.assert_eq[USize](0, f.allocated())
    // overhead must saturate rather than underflow.
    h.assert_eq[USize](0, f.overhead())
*/
class \nodoc\ iso _TestEmptyArray is UnitTest
  fun name(): String => "meminfo/array/empty"

  fun apply(h: TestHelper) =>
    let mi: ArrayMemType = MemInfo.array[U64](Array[U64])

    h.assert_eq[USize](0, ArrayMem.p_alloc(mi))
    h.assert_eq[USize](0, ArrayMem.a_reserved(mi))
    h.assert_eq[USize](0, ArrayMem.a_count(mi))
    h.assert_eq[USize](8, ArrayMem.e_size(mi))

class \nodoc\ iso _TestStringBufferExact is UnitTest
  fun name(): String => "meminfo/string/buffer_exact"

  fun apply(h: TestHelper) =>
    let s: String val = "hello world".clone() // 11 heap bytes of content
    let mi: StringMemType = MemInfo.string(s)
    h.assert_eq[USize](32, StringMem.p_alloc(mi))
    h.assert_eq[USize](12, StringMem.s_reserved(mi))
    h.assert_eq[USize](11, StringMem.s_size(mi))
    h.assert_eq[USize](32, StringMem.s_logical(mi))
    h.assert_eq[USize](32, StringMem.s_alloc(mi))

class \nodoc\ iso _TestArrayElementSize is UnitTest
  fun name(): String => "meminfo/array/element_size"

  fun apply(h: TestHelper) =>
    // U64 elements: 8 bytes each.
    let ami: ArrayMemType = MemInfo.array[U64]([as U64: 1; 2; 3])
    h.assert_eq[USize](64, ArrayMem.p_alloc(ami))
    h.assert_eq[USize](8, ArrayMem.a_reserved(ami))
    h.assert_eq[USize](3, ArrayMem.a_count(ami))
    h.assert_eq[USize](8, ArrayMem.e_size(ami))
    h.assert_eq[USize](24, ArrayMem.a_count(ami) * ArrayMem.e_size(ami))

    let bmi: ArrayMemType = MemInfo.array[U64]([as U64: 1; 2; 3; 4; 5; 6; 7; 8; 9; 10])
    h.assert_eq[USize](128, ArrayMem.p_alloc(bmi))
    h.assert_eq[USize](16, ArrayMem.a_reserved(bmi))
    h.assert_eq[USize](10, ArrayMem.a_count(bmi))
    h.assert_eq[USize](8, ArrayMem.e_size(bmi))
    h.assert_eq[USize](80, ArrayMem.a_count(bmi) * ArrayMem.e_size(bmi))

    // U16 elements: 2 bytes each.
    let cmi: ArrayMemType = MemInfo.array[U16]([as U16: 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11])
    h.assert_eq[USize](32, ArrayMem.p_alloc(cmi))
    h.assert_eq[USize](16, ArrayMem.a_reserved(cmi))
    h.assert_eq[USize](11, ArrayMem.a_count(cmi))
    h.assert_eq[USize](2, ArrayMem.e_size(cmi))
    h.assert_eq[USize](22, ArrayMem.a_count(cmi) * ArrayMem.e_size(cmi))
/*
class \nodoc\ iso _TestDerivedArithmetic is UnitTest
  fun name(): String => "meminfo/derived/arithmetic"

  fun apply(h: TestHelper) =>
    let a = Array[U8](10)
    a.push(1); a.push(2)
    let f = MemInfo.array[U8](a)
    h.assert_eq[USize](f.object_alloc + f.buffer_alloc, f.allocated())
    h.assert_eq[USize](f.object_size + f.buffer_used, f.logical())
    h.assert_true(f.allocated() >= f.logical())
    h.assert_eq[USize](f.allocated() - f.logical(), f.overhead())
*/
class \nodoc\ iso _StringFootprintProperty is Property1[String]
  """For any string, the buffer's in-use bytes equal its byte length."""
  fun name(): String => "meminfo/property/string"

  fun gen(): Generator[String] =>
    Generators.byte_string(Generators.u8(), 0, 200)

  fun ref property(s: String, ph: PropertyHelper) =>
    let mi: StringMemType = MemInfo.string(s)
    ph.assert_eq[USize](s.size(), StringMem.s_size(mi))
/*

class \nodoc\ iso _ArrayU8FootprintProperty is Property1[USize]
  """For an Array[U8] of length n, the buffer holds exactly n bytes."""
  fun name(): String => "meminfo/property/array_u8"

  fun gen(): Generator[USize] =>
    Generators.usize(0, 500)

  fun ref property(n: USize, ph: PropertyHelper) =>
    let a = Array[U8](n)
    var i: USize = 0
    while i < n do
      a.push(i.u8())
      i = i + 1
    end
    let f = MemInfo.array[U8](a)
    ph.assert_eq[USize](n, f.buffer_used)
    ph.assert_true(f.buffer_alloc >= f.buffer_used)
    ph.assert_true(f.allocated() >= f.logical())
    if n > 0 then
      ph.assert_true(f.buffer_alloc > 0)
    end

class \nodoc\ iso _ArrayU64FootprintProperty is Property1[USize]
  """For an Array[U64] of length n, the buffer holds exactly n*8 bytes."""
  fun name(): String => "meminfo/property/array_u64"

  fun gen(): Generator[USize] =>
    Generators.usize(0, 200)

  fun ref property(n: USize, ph: PropertyHelper) =>
    let a = Array[U64](n)
    var i: USize = 0
    while i < n do
      a.push(i.u64())
      i = i + 1
    end
    let f = MemInfo.array[U64](a)
    ph.assert_eq[USize](n * 8, f.buffer_used)
    ph.assert_true(f.buffer_alloc >= f.buffer_used)
    if n > 0 then
      ph.assert_true(f.buffer_alloc > 0)
    end
*/

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
  fun name(): String => "meminfo/deep/string_matches_shallow"

  fun apply(h: TestHelper) =>
    let s: String val = "hello world".clone()
    let deep = MemInfo.deep(s)
    let shallow = MemInfo.string(s)
    // A String is one object plus one backing buffer; deep must agree with the
    // shallow string measurement's total.
    h.assert_eq[USize](
      StringMem.s_alloc(shallow) + StringMem.p_alloc(shallow),
      DeepMem.allocated(deep))
    h.assert_eq[USize](1, DeepMem.object_count(deep))
    h.assert_eq[USize](1, DeepMem.buffer_count(deep))
    h.assert_eq[USize](0, DeepMem.actor_refs(deep))

class \nodoc\ iso _TestDeepNestedSum is UnitTest
  fun name(): String => "meminfo/deep/nested_sum"

  fun apply(h: TestHelper) =>
    let p = _Pair
    let deep = MemInfo.deep(p)
    let label = MemInfo.string(p.label)
    let nums = MemInfo.array[U64](p.nums)
    // Cross-check the transitive total against the sum of the shallow slots of
    // each distinct component (no sharing in _Pair).
    let expect =
      FlatMem.alloc(MemInfo.flat(p))
        + (StringMem.s_alloc(label) + StringMem.p_alloc(label))
        + (ArrayMem.s_alloc(nums) + ArrayMem.p_alloc(nums))
    h.assert_eq[USize](expect, DeepMem.allocated(deep))
    // 3 objects: the pair, the string, the array.
    h.assert_eq[USize](3, DeepMem.object_count(deep))
    // 2 buffers: the string's bytes, the array's elements.
    h.assert_eq[USize](2, DeepMem.buffer_count(deep))

class \nodoc\ iso _TestDeepSharingDeduped is UnitTest
  fun name(): String => "meminfo/deep/sharing_deduped"

  fun apply(h: TestHelper) =>
    // The same String object referenced four times must be counted once.
    let s: String val = "shared-value".clone()
    let arr = [s; s; s; s]
    let deep = MemInfo.deep(arr)
    h.assert_eq[USize](2, DeepMem.object_count(deep)) // the array + one shared string
    let arr_m = MemInfo.array[String](arr)
    let s_m = MemInfo.string(s)
    let expect =
      (ArrayMem.s_alloc(arr_m) + ArrayMem.p_alloc(arr_m))
        + (StringMem.s_alloc(s_m) + StringMem.p_alloc(s_m))
    h.assert_eq[USize](expect, DeepMem.allocated(deep))

class \nodoc\ iso _TestDeepCycleTerminates is UnitTest
  fun name(): String => "meminfo/deep/cycle_terminates"

  fun apply(h: TestHelper) =>
    // A self-referential structure must terminate and count each node once.
    let a: _Cycle ref = _Cycle
    a.next = a
    let deep = MemInfo.deep(a)
    h.assert_eq[USize](2, DeepMem.object_count(deep)) // the node + its payload string
    h.assert_eq[USize](1, DeepMem.buffer_count(deep))
    h.assert_true(DeepMem.allocated(deep) > 0)

class \nodoc\ iso _TestDeepActorBoundary is UnitTest
  fun name(): String => "meminfo/deep/actor_boundary"

  fun apply(h: TestHelper) =>
    let obj: _HoldsActor ref = _HoldsActor(_DeepDummyActor)
    let deep = MemInfo.deep(obj)
    // The actor is referenced but not traversed.
    h.assert_eq[USize](1, DeepMem.actor_refs(deep))
    h.assert_eq[USize](2, DeepMem.object_count(deep)) // the holder + its label string
    h.assert_eq[USize](1, DeepMem.buffer_count(deep))
    // The actor's heap is excluded: total is just the owned data.
    let label = MemInfo.string(obj.label)
    let expect =
      FlatMem.alloc(MemInfo.flat(obj))
        + (StringMem.s_alloc(label) + StringMem.p_alloc(label))
    h.assert_eq[USize](expect, DeepMem.allocated(deep))

class \nodoc\ iso _DeepArrayOfStringsProperty is Property1[USize]
  """
  An Array of n distinct non-empty strings has n+1 objects (array + strings)
  and n+1 buffers (the array's pointer storage + each string's bytes), and its
  transitive total equals the summed shallow slots of its parts.
  """
  fun name(): String => "meminfo/deep/property/array_of_strings"

  fun gen(): Generator[USize] =>
    Generators.usize(1, 30)

  fun ref property(n: USize, ph: PropertyHelper) =>
    let arr = Array[String](n)
    var i: USize = 0
    while i < n do
      arr.push("element".clone()) // each clone is a distinct object
      i = i + 1
    end
    let deep = MemInfo.deep(arr)
    ph.assert_eq[USize](n + 1, DeepMem.object_count(deep))
    ph.assert_eq[USize](n + 1, DeepMem.buffer_count(deep))

    let arr_m = MemInfo.array[String](arr)
    var expect = ArrayMem.s_alloc(arr_m) + ArrayMem.p_alloc(arr_m)
    for s in arr.values() do
      let s_m = MemInfo.string(s)
      expect = expect + StringMem.s_alloc(s_m) + StringMem.p_alloc(s_m)
    end
    ph.assert_eq[USize](expect, DeepMem.allocated(deep))

// ------------------------------------------------------ whole-actor heap walk

class \nodoc\ iso _TestActorHeapLargeDelta is UnitTest
  fun name(): String => "meminfo/actor/large_delta"

  fun apply(h: TestHelper) =>
    // A buffer larger than the 512-byte small-class max becomes a large
    // allocation, so it must show up in the large-chunk list.
    let before = MemInfo.actor_self()
    let big = Array[U8](4096)
    big.push(0)
    let after = MemInfo.actor_self()
    h.assert_true(ActorMem.large_chunks(after) > ActorMem.large_chunks(before),
      "a large allocation must add a large chunk")
    h.assert_true(ActorMem.in_use(after) >= (ActorMem.in_use(before) + 4096),
      "in_use must grow by at least the large allocation")
    h.assert_true(ActorMem.reserved(after) >= ActorMem.in_use(after))
    h.assert_true(big.size() == 1) // keep big alive past the second measurement

class \nodoc\ iso _TestActorHeapSmallDelta is UnitTest
  fun name(): String => "meminfo/actor/small_delta"

  fun apply(h: TestHelper) =>
    // 200 small objects, kept alive, must add at least 200 used small slots.
    let before = MemInfo.actor_self()
    let keep = Array[_TwoWords](200)
    var i: USize = 0
    while i < 200 do
      keep.push(_TwoWords)
      i = i + 1
    end
    let after = MemInfo.actor_self()
    h.assert_true(
      ActorMem.small_slots_used(after) >= (ActorMem.small_slots_used(before) + 200),
      "200 small objects must add >= 200 used slots")
    h.assert_true(ActorMem.in_use(after) > ActorMem.in_use(before))
    h.assert_true(keep.size() == 200) // keep them alive
