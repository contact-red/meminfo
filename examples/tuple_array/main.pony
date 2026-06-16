use "collections"
use "../../meminfo"

actor Main
  let env: Env
  new create(env': Env) =>
    env = env'

    let st: Array[TupleType] = Array[TupleType](10)
    var mi: ArrayMemType = MemInfo.array[TupleType](st)
    env.out.print("Test size: ")
    env.out.print("  p_alloc:    " + ArrayMem.p_alloc(mi).string())
    env.out.print("  a_reserved: " + ArrayMem.a_reserved(mi).string())
    env.out.print("  a_count:    " + ArrayMem.a_count(mi).string())
    env.out.print("  e_size:     " + ArrayMem.e_size(mi).string())

    st.push((TupleTag, 8, 16, 32, 64, 128))
    mi = MemInfo.array[TupleType](st)
    env.out.print("Test size: ")
    env.out.print("  p_alloc:    " + ArrayMem.p_alloc(mi).string())
    env.out.print("  a_reserved: " + ArrayMem.a_reserved(mi).string())
    env.out.print("  a_count:    " + ArrayMem.a_count(mi).string())
    env.out.print("  e_size:     " + ArrayMem.e_size(mi).string())

primitive TupleTag
type TupleType is (TupleTag, U8, U16, U32, U64, U128)

