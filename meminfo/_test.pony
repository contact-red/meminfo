use "pony_test"
use "pony_check"

actor \nodoc\ Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    // Flat mode.
    test(_TestFlatStructSize)
    test(_TestFlatActorZeroSlot)
    test(_TestFlatAllocGteLogical)

    // String mode.
    test(_TestStringBufferExact)
    test(_TestStringEmpty)
    test(_TestStringSizeClassBoundaries)
    test(Property1UnitTest[String](_StringSizeProperty))
    test(Property1UnitTest[USize](_StringSlotInvariantsProperty))

    // Array mode.
    test(_TestArrayEmpty)
    test(_TestArrayElementSize)
    test(Property1UnitTest[USize](_ArrayU8FootprintProperty))
    test(Property1UnitTest[USize](_ArrayU64FootprintProperty))
    test(Property1UnitTest[USize](_ArrayStringFootprintProperty))
    test(Property1UnitTest[USize](_ArrayElementSizeInvariantProperty))

    // Deep mode.
    test(_TestDeepLeafObject)
    test(_TestDeepStringMatchesShallow)
    test(_TestDeepNestedSum)
    test(_TestDeepSharingDeduped)
    test(_TestDeepDiamondSharing)
    test(_TestDeepCycleTerminates)
    test(_TestDeepMultiCycle)
    test(_TestDeepActorBoundary)
    test(Property1UnitTest[USize](_DeepArrayOfStringsProperty))
    test(Property1UnitTest[USize](_DeepChainProperty))
    test(Property1UnitTest[USize](_DeepSharingDegreeProperty))
    test(Property1UnitTest[USize](_DeepGraphSwarmProperty))

    // Whole-actor heap walk.
    test(_TestActorHeapBaseline)
    test(_TestActorHeapDerivedFields)
    test(_TestActorHeapLargeDelta)
    test(_TestActorHeapSmallDelta)
    test(Property1UnitTest[USize](_ActorHeapReservedGteInUseProperty))
