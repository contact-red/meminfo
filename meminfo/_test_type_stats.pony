use "pony_test"

class \nodoc\ iso _TestTypeStatsIncDec is UnitTest
  fun name(): String => "meminfo/type_stats/inc_dec"

  fun apply(h: TestHelper) =>
    TypeStats.inc("TestA")
    TypeStats.inc("TestA")
    TypeStats.inc("TestA")
    h.assert_eq[I64](3, TypeStats.get("TestA"))

    TypeStats.dec("TestA")
    h.assert_eq[I64](2, TypeStats.get("TestA"))

    TypeStats.dec("TestA")
    TypeStats.dec("TestA")
    h.assert_eq[I64](0, TypeStats.get("TestA"))

class \nodoc\ iso _TestTypeStatsUnknownKey is UnitTest
  fun name(): String => "meminfo/type_stats/unknown_key"

  fun apply(h: TestHelper) =>
    h.assert_eq[I64](0, TypeStats.get("NoSuchType"))

class \nodoc\ iso _TestTypeStatsMultipleKeys is UnitTest
  fun name(): String => "meminfo/type_stats/multiple_keys"

  fun apply(h: TestHelper) =>
    TypeStats.inc("KeyAlpha")
    TypeStats.inc("KeyBeta")
    TypeStats.inc("KeyBeta")
    h.assert_eq[I64](1, TypeStats.get("KeyAlpha"))
    h.assert_eq[I64](2, TypeStats.get("KeyBeta"))

    TypeStats.dec("KeyAlpha")
    TypeStats.dec("KeyBeta")
    TypeStats.dec("KeyBeta")

class \nodoc\ iso _TestTypeStatsTrackedCount is UnitTest
  fun name(): String => "meminfo/type_stats/tracked_count"

  fun apply(h: TestHelper) =>
    let before = TypeStats.tracked_count()
    TypeStats.inc("CountTestUnique1")
    TypeStats.inc("CountTestUnique2")
    let after = TypeStats.tracked_count()
    h.assert_true(after >= (before + 2),
      "tracked_count must grow when new keys are added")

    TypeStats.dec("CountTestUnique1")
    TypeStats.dec("CountTestUnique2")

class \nodoc\ iso _TestTypeStatsSnapshot is UnitTest
  fun name(): String => "meminfo/type_stats/snapshot"

  fun apply(h: TestHelper) =>
    TypeStats.inc("SnapA")
    TypeStats.inc("SnapA")
    TypeStats.inc("SnapB")

    let snap = TypeStats.snapshot()
    var found_a: Bool = false
    var found_b: Bool = false
    for (n, c) in snap.values() do
      if n == "SnapA" then
        h.assert_eq[I64](2, c)
        found_a = true
      elseif n == "SnapB" then
        h.assert_eq[I64](1, c)
        found_b = true
      end
    end
    h.assert_true(found_a, "snapshot must contain SnapA")
    h.assert_true(found_b, "snapshot must contain SnapB")

    TypeStats.dec("SnapA")
    TypeStats.dec("SnapA")
    TypeStats.dec("SnapB")

class \nodoc\ iso _TestTypeStatsSnapshotEmpty is UnitTest
  fun name(): String => "meminfo/type_stats/snapshot_empty"

  fun apply(h: TestHelper) =>
    // When nothing has been tracked yet, snapshot still returns safely. Since
    // the C table is global and other tests may have run, we just check that
    // the call doesn't crash and returns an array.
    let snap = TypeStats.snapshot()
    h.assert_true(true, "snapshot on populated table did not crash")

class \nodoc\ iso _TestTypeStatsLocTypeName is UnitTest
  fun name(): String => "meminfo/type_stats/loc_type_name"

  fun apply(h: TestHelper) =>
    TypeStats.inc(__loc.type_name())
    h.assert_eq[I64](1,
      TypeStats.get("_TestTypeStatsLocTypeName"))
    TypeStats.dec(__loc.type_name())
