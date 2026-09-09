use "pony_test"
use "pony_check"

class \nodoc\ iso _TestDeepLeafObject is UnitTest
  fun name(): String => "meminfo/deep/leaf_object"

  fun apply(h: TestHelper) =>
    let obj: _TwoWords ref = _TwoWords
    let deep = MemInfo.deep(obj)
    let flat = MemInfo.flat(obj)
    h.assert_eq[USize](FlatMem.alloc(flat), DeepMem.allocated(deep))
    h.assert_eq[USize](1, DeepMem.object_count(deep))
    h.assert_eq[USize](0, DeepMem.buffer_count(deep))
    h.assert_eq[USize](0, DeepMem.actor_refs(deep))

class \nodoc\ iso _TestDeepStringMatchesShallow is UnitTest
  fun name(): String => "meminfo/deep/string_matches_shallow"

  fun apply(h: TestHelper) =>
    let s: String val = "hello world".clone()
    let deep = MemInfo.deep(s)
    let shallow = MemInfo.string(s)
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
    let expect =
      FlatMem.alloc(MemInfo.flat(p))
        + (StringMem.s_alloc(label) + StringMem.p_alloc(label))
        + (ArrayMem.s_alloc(nums) + ArrayMem.p_alloc(nums))
    h.assert_eq[USize](expect, DeepMem.allocated(deep))
    h.assert_eq[USize](3, DeepMem.object_count(deep))
    h.assert_eq[USize](2, DeepMem.buffer_count(deep))

class \nodoc\ iso _TestDeepSharingDeduped is UnitTest
  fun name(): String => "meminfo/deep/sharing_deduped"

  fun apply(h: TestHelper) =>
    let s: String val = "shared-value".clone()
    let arr = [s; s; s; s]
    let deep = MemInfo.deep(arr)
    h.assert_eq[USize](2, DeepMem.object_count(deep))
    let arr_m = MemInfo.array[String](arr)
    let s_m = MemInfo.string(s)
    let expect =
      (ArrayMem.s_alloc(arr_m) + ArrayMem.p_alloc(arr_m))
        + (StringMem.s_alloc(s_m) + StringMem.p_alloc(s_m))
    h.assert_eq[USize](expect, DeepMem.allocated(deep))

class \nodoc\ iso _TestDeepDiamondSharing is UnitTest
  fun name(): String => "meminfo/deep/diamond_sharing"

  fun apply(h: TestHelper) =>
    let shared: String val = "diamond-tip".clone()
    let d = _Diamond(shared)
    let deep = MemInfo.deep(d)
    // 4 objects: _Diamond, left _DiamondArm, right _DiamondArm, shared String.
    h.assert_eq[USize](4, DeepMem.object_count(deep))
    // 1 buffer: the shared string's backing bytes.
    h.assert_eq[USize](1, DeepMem.buffer_count(deep))
    // Cross-check: total equals sum of parts with shared String counted once.
    let d_flat = FlatMem.alloc(MemInfo.flat(d))
    let left_flat = FlatMem.alloc(MemInfo.flat(d.left))
    let right_flat = FlatMem.alloc(MemInfo.flat(d.right))
    let s_m = MemInfo.string(shared)
    let expect =
      d_flat + left_flat + right_flat
        + (StringMem.s_alloc(s_m) + StringMem.p_alloc(s_m))
    h.assert_eq[USize](expect, DeepMem.allocated(deep))

class \nodoc\ iso _TestDeepCycleTerminates is UnitTest
  fun name(): String => "meminfo/deep/cycle_terminates"

  fun apply(h: TestHelper) =>
    let a: _Cycle ref = _Cycle
    a.next = a
    let deep = MemInfo.deep(a)
    h.assert_eq[USize](2, DeepMem.object_count(deep))
    h.assert_eq[USize](1, DeepMem.buffer_count(deep))
    h.assert_true(DeepMem.allocated(deep) > 0)

class \nodoc\ iso _TestDeepMultiCycle is UnitTest
  fun name(): String => "meminfo/deep/multi_cycle"

  fun apply(h: TestHelper) =>
    // A → B → C → A
    let a: _Cycle ref = _Cycle
    let b: _Cycle ref = _Cycle
    let c: _Cycle ref = _Cycle
    a.next = b
    b.next = c
    c.next = a
    let deep = MemInfo.deep(a)
    // 3 _Cycle nodes + 3 payload strings = 6 objects.
    h.assert_eq[USize](6, DeepMem.object_count(deep))
    // 3 string backing buffers.
    h.assert_eq[USize](3, DeepMem.buffer_count(deep))
    h.assert_eq[USize](0, DeepMem.actor_refs(deep))

class \nodoc\ iso _TestDeepActorBoundary is UnitTest
  fun name(): String => "meminfo/deep/actor_boundary"

  fun apply(h: TestHelper) =>
    let obj = _HoldsActor(_DeepDummyActor)
    let deep = MemInfo.deep(obj)
    h.assert_eq[USize](1, DeepMem.actor_refs(deep))
    h.assert_eq[USize](2, DeepMem.object_count(deep))
    h.assert_eq[USize](1, DeepMem.buffer_count(deep))
    let label = MemInfo.string(obj.label)
    let expect =
      FlatMem.alloc(MemInfo.flat(obj))
        + (StringMem.s_alloc(label) + StringMem.p_alloc(label))
    h.assert_eq[USize](expect, DeepMem.allocated(deep))

class \nodoc\ iso _DeepArrayOfStringsProperty is Property1[USize]
  fun name(): String => "meminfo/deep/property/array_of_strings"

  fun gen(): Generator[USize] =>
    Generators.usize(1, 30)

  fun ref property(n: USize, ph: PropertyHelper) =>
    let arr = Array[String](n)
    var i: USize = 0
    while i < n do
      arr.push("element".clone())
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

class \nodoc\ iso _DeepChainProperty is Property1[USize]
  fun name(): String => "meminfo/deep/property/chain"

  fun gen(): Generator[USize] =>
    Generators.usize(1, 20)

  fun ref property(n: USize, ph: PropertyHelper) =>
    var head = _GraphNode(_MakeString(5))
    var i: USize = 1
    while i < n do
      let node = _GraphNode(_MakeString(5))
      node.next = head
      head = node
      i = i + 1
    end
    let deep = MemInfo.deep(head)
    // n _GraphNode objects + n payload strings = 2n objects.
    ph.assert_eq[USize](n * 2, DeepMem.object_count(deep))
    // n string backing buffers.
    ph.assert_eq[USize](n, DeepMem.buffer_count(deep))
    ph.assert_eq[USize](0, DeepMem.actor_refs(deep))
    ph.assert_eq[USize](
      DeepMem.object_alloc(deep) + DeepMem.buffer_alloc(deep),
      DeepMem.allocated(deep))
    ph.assert_eq[USize](
      DeepMem.object_count(deep) + DeepMem.buffer_count(deep),
      DeepMem.count(deep))

class \nodoc\ iso _DeepSharingDegreeProperty is Property1[USize]
  fun name(): String => "meminfo/deep/property/sharing_degree"

  fun gen(): Generator[USize] =>
    Generators.usize(1, 10)

  fun ref property(k: USize, ph: PropertyHelper) =>
    let shared: String val = "shared-payload".clone()
    let arr = Array[String](k)
    var i: USize = 0
    while i < k do
      arr.push(shared)
      i = i + 1
    end
    let deep = MemInfo.deep(arr)
    // Always 2 objects (the array + the one shared string) regardless of k.
    ph.assert_eq[USize](2, DeepMem.object_count(deep))
    // Always 2 buffers (the array's pointer buffer + the string's bytes).
    ph.assert_eq[USize](2, DeepMem.buffer_count(deep))

class \nodoc\ iso _DeepGraphSwarmProperty is Property1[USize]
  """
  Swarm testing for deep mode: each test run builds a graph from a randomly
  chosen subset of operations, pushing each run into a different structural
  extreme. The invariants checked are properties that hold regardless of
  graph shape.
  """
  fun name(): String => "meminfo/deep/property/graph_swarm"

  fun gen(): Generator[USize] =>
    // Encode the swarm configuration + chain length in a single USize.
    // Bits 0-3: operation enables (unique, shared, cycle, actor).
    // Bits 4+: chain length (1..15).
    // We use flat_map to decode and build, but PonyCheck's flat_map shrinking
    // is incomplete, so we pack into one value and decode in property().
    Generators.frequency[USize]([
      as WeightedGenerator[USize]:
      (4, Generators.usize(0x10, 0xFF))
      (1, Generators.one_of[USize](
        // Force single-operation configurations for swarm diversity.
        [as USize:
          0x31  // unique only, len 3
          0x32  // shared only, len 3
          0x34  // cycle only, len 3
          0x38  // actor only, len 3
          0xF1  // all ops, len 15
          0x11  // unique only, len 1
        ]))
    ])

  fun ref property(encoded: USize, ph: PropertyHelper) =>
    let ops_unique = (encoded and 0x1) != 0
    let ops_shared = (encoded and 0x2) != 0
    let ops_cycle  = (encoded and 0x4) != 0
    let ops_actor  = (encoded and 0x8) != 0
    let chain_len  = ((encoded >> 4) and 0xF).max(1)

    // At least one non-cycle operation must be enabled to build anything.
    if (not ops_unique) and (not ops_shared) and (not ops_actor) then
      return
    end

    let shared_str: String val = "swarm-shared".clone()
    var actors_added: USize = 0
    var unique_payloads: USize = 0

    var head = _GraphNode(
      if ops_unique then
        unique_payloads = unique_payloads + 1
        _MakeString(10)
      else
        shared_str
      end)

    if ops_actor then
      head.actor_ref = _DeepDummyActor
      actors_added = actors_added + 1
    end

    var i: USize = 1
    while i < chain_len do
      let payload: String val =
        if ops_unique and ((not ops_shared) or ((i % 2) == 0)) then
          unique_payloads = unique_payloads + 1
          _MakeString(10)
        else
          shared_str
        end
      let node = _GraphNode(payload)
      node.next = head
      if ops_actor and ((i % 3) == 0) then
        node.actor_ref = _DeepDummyActor
        actors_added = actors_added + 1
      end
      head = node
      i = i + 1
    end

    if ops_cycle and (chain_len > 1) then
      // Walk to the tail and point it back at the head.
      var cursor: _GraphNode = head
      while true do
        match cursor.next
        | let n: _GraphNode => cursor = n
        | None => break
        end
      end
      cursor.next = head
    end

    let deep = MemInfo.deep(head)

    // Structural invariants that hold regardless of configuration.
    ph.assert_eq[USize](
      DeepMem.object_alloc(deep) + DeepMem.buffer_alloc(deep),
      DeepMem.allocated(deep),
      "allocated = object_alloc + buffer_alloc")
    ph.assert_eq[USize](
      DeepMem.object_count(deep) + DeepMem.buffer_count(deep),
      DeepMem.count(deep),
      "count = object_count + buffer_count")
    ph.assert_true(DeepMem.allocated(deep) > 0,
      "a non-empty graph always has some allocation")
    ph.assert_true(DeepMem.object_count(deep) >= 1,
      "at least the root is counted")

    // Actor ref count: each distinct actor is counted once.
    if not ops_actor then
      ph.assert_eq[USize](0, DeepMem.actor_refs(deep),
        "no actors added, none should be counted")
    else
      ph.assert_true(DeepMem.actor_refs(deep) <= actors_added,
        "actor_refs <= actors added (dedup may reduce count)")
      ph.assert_true(DeepMem.actor_refs(deep) > 0,
        "at least one actor was added")
    end

    // When all payloads are unique (no sharing), we know the exact count.
    if ops_unique and (not ops_shared) then
      // chain_len nodes + chain_len payload strings = 2 * chain_len objects.
      ph.assert_eq[USize](chain_len * 2, DeepMem.object_count(deep),
        "unique payloads: 2 objects per node")
      // chain_len string backing buffers.
      ph.assert_eq[USize](chain_len, DeepMem.buffer_count(deep),
        "unique payloads: one buffer per string")
    end

    // When all payloads are shared, the shared string is counted once.
    if ops_shared and (not ops_unique) then
      // chain_len nodes + 1 shared string = chain_len + 1 objects.
      ph.assert_eq[USize](chain_len + 1, DeepMem.object_count(deep),
        "shared payloads: one shared string object")
      // 1 buffer for the shared string's bytes.
      ph.assert_eq[USize](1, DeepMem.buffer_count(deep),
        "shared payloads: one shared buffer")
    end
