use "collections"
use "../../meminfo"

actor Main
  let env: Env
  let s: String val = "X".mul(400)
  new create(env': Env) =>
    env = env'
    let m = MemInfo.string(s)
    env.out.print(
      "string struct alloc=" + StringMem.s_alloc(m).string()
        + " buffer alloc=" + StringMem.p_alloc(m).string()
        + " used=" + StringMem.s_size(m).string())
    Two(this, env)

  be gimmie(two: Two tag) =>
    two.receive(s)




actor Two
  let env: Env
  new create(main: Main tag, env': Env) =>
    env = env'
    _show()
    main.gimmie(this)

  be receive(s: String val) =>
    _show()

  fun _show() =>
    let h = MemInfo.actor_self()
    env.out.print(
      "actor in_use=" + ActorMem.in_use(h).string()
        + " reserved=" + ActorMem.reserved(h).string())
