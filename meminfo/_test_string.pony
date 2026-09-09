use "pony_test"
use "pony_check"

class \nodoc\ iso _TestStringBufferExact is UnitTest
  fun name(): String => "meminfo/string/buffer_exact"

  fun apply(h: TestHelper) =>
    let s: String val = "hello world".clone()
    let mi = MemInfo.string(s)
    h.assert_eq[USize](32, StringMem.p_alloc(mi))
    h.assert_eq[USize](32, StringMem.s_reserved(mi))
    h.assert_eq[USize](11, StringMem.s_size(mi))
    h.assert_eq[USize](32, StringMem.s_logical(mi))
    h.assert_eq[USize](32, StringMem.s_alloc(mi))

class \nodoc\ iso _TestStringEmpty is UnitTest
  fun name(): String => "meminfo/string/empty"

  fun apply(h: TestHelper) =>
    let s: String val = "".clone()
    let mi = MemInfo.string(s)
    h.assert_eq[USize](0, StringMem.s_size(mi))
    h.assert_eq[USize](32, StringMem.s_alloc(mi),
      "the String struct is still heap-allocated")
    h.assert_true(StringMem.s_alloc(mi) >= StringMem.s_logical(mi))

class \nodoc\ iso _TestStringSizeClassBoundaries is UnitTest
  fun name(): String => "meminfo/string/size_class_boundaries"

  fun apply(h: TestHelper) =>
    // String allocates space() + 1 for the null terminator, so a string of
    // length n needs n+1 bytes of buffer. The allocator rounds up to the next
    // size class (32, 64, 128, 256, 512, then large allocations).
    //
    // At clone() time, the reserved capacity is the allocation slot size.
    // A string of length 31 needs 32 bytes (31 content + 1 terminator) → 32.
    // A string of length 32 needs 33 bytes → 64.
    _check(h, 31, 32)
    _check(h, 32, 64)
    _check(h, 33, 64)
    _check(h, 63, 64)
    _check(h, 64, 128)
    _check(h, 65, 128)
    _check(h, 127, 128)
    _check(h, 128, 256)
    _check(h, 255, 256)
    _check(h, 256, 512)
    _check(h, 511, 512)
    _check(h, 512, 1024)

  fun _check(h: TestHelper, len: USize, expected_slot: USize) =>
    let s: String val = _MakeString(len)
    let mi = MemInfo.string(s)
    h.assert_eq[USize](len, StringMem.s_size(mi),
      "s_size for len=" + len.string())
    h.assert_eq[USize](expected_slot, StringMem.p_alloc(mi),
      "p_alloc for len=" + len.string())

class \nodoc\ iso _StringSizeProperty is Property1[String]
  fun name(): String => "meminfo/string/property/size"

  fun gen(): Generator[String] =>
    Generators.byte_string(Generators.u8(), 0, 200)

  fun ref property(s: String, ph: PropertyHelper) =>
    let mi = MemInfo.string(s)
    ph.assert_eq[USize](s.size(), StringMem.s_size(mi))

class \nodoc\ iso _StringSlotInvariantsProperty is Property1[USize]
  fun name(): String => "meminfo/string/property/slot_invariants"

  fun gen(): Generator[USize] =>
    _SizeClassBiasedLen.gen()

  fun ref property(n: USize, ph: PropertyHelper) =>
    let s: String val = _MakeString(n)
    let mi = MemInfo.string(s)
    ph.assert_eq[USize](s.size(), StringMem.s_size(mi))
    ph.assert_eq[USize](s.space() + 1, StringMem.s_reserved(mi))
    ph.assert_true(StringMem.s_alloc(mi) >= StringMem.s_logical(mi),
      "struct slot must fit the struct")
    if s.size() > 0 then
      ph.assert_true(StringMem.p_alloc(mi) > 0,
        "non-empty string must have a buffer allocation")
      ph.assert_true(StringMem.p_alloc(mi) >= StringMem.s_reserved(mi),
        "buffer slot must fit the reserved capacity")
    end
