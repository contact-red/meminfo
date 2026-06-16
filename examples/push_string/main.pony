use "collections"
use "../../meminfo"

actor Main
  let env: Env
  new create(env': Env) =>
    env = env'
    let h = MemInfo.actor_self() // Stack
    env.out.print("actor in_use=" + ActorMem.in_use(h).string()
      + " reserved=" + ActorMem.reserved(h).string())

    let s: String trn = recover trn String end
    for f in Range[USize](0, 100) do
      s.push('x')
      _show(s)
    end

  fun _show(s: String box) =>
    let m = MemInfo.string(s)
    env.out.print(s.cpointer().usize().string() + ": "
      + "alloc=" + StringMem.p_alloc(m).string()
      + " reserved=" + StringMem.s_reserved(m).string()
      + " used=" + StringMem.s_size(m).string())

