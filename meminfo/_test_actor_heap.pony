use "pony_test"
use "pony_check"

class \nodoc\ iso _TestActorHeapBaseline is UnitTest
  fun name(): String => "meminfo/actor/baseline"

  fun apply(h: TestHelper) =>
    let m = MemInfo.actor_self()
    h.assert_true(ActorMem.in_use(m) > 0,
      "even an idle actor has some heap content")
    h.assert_true(ActorMem.reserved(m) > 0)
    h.assert_true(ActorMem.reserved(m) >= ActorMem.in_use(m),
      "reserved must be >= in_use")

class \nodoc\ iso _TestActorHeapDerivedFields is UnitTest
  fun name(): String => "meminfo/actor/derived_fields"

  fun apply(h: TestHelper) =>
    // Allocate some objects so the derived fields have non-trivial values.
    let keep = Array[_TwoWords](50)
    var i: USize = 0
    while i < 50 do
      keep.push(_TwoWords)
      i = i + 1
    end
    let big = Array[U8](4096)
    big.push(0)

    let m = MemInfo.actor_self()
    h.assert_eq[USize](
      ActorMem.small_slots_used(m) + ActorMem.large_chunks(m),
      ActorMem.allocations(m),
      "allocations = small_slots_used + large_chunks")
    if ActorMem.reserved(m) >= ActorMem.in_use(m) then
      h.assert_eq[USize](
        ActorMem.reserved(m) - ActorMem.in_use(m),
        ActorMem.overhead(m),
        "overhead = reserved - in_use")
    else
      h.assert_eq[USize](0, ActorMem.overhead(m),
        "overhead saturates at 0")
    end
    h.assert_true(keep.size() == 50)
    h.assert_true(big.size() == 1)

class \nodoc\ iso _TestActorHeapLargeDelta is UnitTest
  fun name(): String => "meminfo/actor/large_delta"

  fun apply(h: TestHelper) =>
    let before = MemInfo.actor_self()
    let big = Array[U8](4096)
    big.push(0)
    let after = MemInfo.actor_self()
    h.assert_true(ActorMem.large_chunks(after) > ActorMem.large_chunks(before),
      "a large allocation must add a large chunk")
    h.assert_true(ActorMem.in_use(after) >= (ActorMem.in_use(before) + 4096),
      "in_use must grow by at least the large allocation")
    h.assert_true(ActorMem.reserved(after) >= ActorMem.in_use(after))
    h.assert_true(big.size() == 1)

class \nodoc\ iso _TestActorHeapSmallDelta is UnitTest
  fun name(): String => "meminfo/actor/small_delta"

  fun apply(h: TestHelper) =>
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
    h.assert_true(keep.size() == 200)

class \nodoc\ iso _ActorHeapReservedGteInUseProperty is Property1[USize]
  fun name(): String => "meminfo/actor/property/reserved_gte_in_use"

  fun gen(): Generator[USize] =>
    Generators.frequency[USize]([
      as WeightedGenerator[USize]:
      (6, Generators.usize(1, 50))
      (1, Generators.one_of[USize]([USize(1); 10; 25; 50]))
    ])

  fun ref property(n: USize, ph: PropertyHelper) =>
    let keep = Array[_TwoWords](n)
    var i: USize = 0
    while i < n do
      keep.push(_TwoWords)
      i = i + 1
    end
    let m = MemInfo.actor_self()
    ph.assert_true(ActorMem.reserved(m) >= ActorMem.in_use(m),
      "reserved >= in_use must hold after any allocation pattern")
    ph.assert_true(
      ActorMem.in_use(m) >= (n * 32),
      "in_use must account for at least n * min_size_class bytes")
    ph.assert_true(keep.size() == n)
