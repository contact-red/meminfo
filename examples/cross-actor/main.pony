use "collections"
use "../../meminfo"

actor Main
  let env: Env
  new create(env': Env) =>
    var s: String iso = "X".mul(516)
    var ss: String iso = "X".mul(516)
    env = env'
    let m = MemInfo.string(consume s)
    env.out.print("Actor Main:")
    env.out.print(
      "string struct alloc=" + StringMem.s_alloc(m).string()
        + " buffer alloc=" + StringMem.p_alloc(m).string()
        + " used=" + StringMem.s_size(m).string())
    Two(this, env, consume ss)


actor Two
  let env: Env
  new create(main: Main tag, env': Env, s: String iso) =>
    env = env'
    env.out.print("Actor Two:")
    let m = MemInfo.string(consume s)
    env.out.print(
      "string struct alloc=" + StringMem.s_alloc(m).string()
        + " buffer alloc=" + StringMem.p_alloc(m).string()
        + " used=" + StringMem.s_size(m).string())
