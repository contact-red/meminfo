use "pony_check"

class \nodoc\ _TwoWords
  var a: U64 = 0
  var b: U64 = 0

class \nodoc\ _ThreeFields
  var x: U64 = 0
  var y: U64 = 0
  var z: U64 = 0

actor \nodoc\ _Dummy
  be noop() => None

class \nodoc\ _Pair
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

class \nodoc\ _Diamond
  let left: _DiamondArm
  let right: _DiamondArm
  new create(shared: String val) =>
    left = _DiamondArm(shared)
    right = _DiamondArm(shared)

class \nodoc\ _DiamondArm
  let tip: String val
  new create(s: String val) => tip = s

class \nodoc\ _GraphNode
  var next: (_GraphNode | None) = None
  var actor_ref: (_DeepDummyActor | None) = None
  let payload: String val

  new create(s: String val) => payload = s

primitive \nodoc\ _SizeClassBiasedLen
  fun gen(): Generator[USize] =>
    Generators.frequency[USize]([
      as WeightedGenerator[USize]:
      (6, Generators.usize(0, 600))
      (1, Generators.one_of[USize](
        [USize(0); 1; 31; 32; 33; 63; 64; 65; 127; 128; 129
         255; 256; 257; 511; 512; 513; 1024; 2048; 4096]))
    ])

primitive \nodoc\ _MakeString
  fun apply(len: USize): String iso^ =>
    let s = recover iso String(len) end
    var i: USize = 0
    while i < len do
      s.push('a')
      i = i + 1
    end
    consume s
