use "collections"
use "../../meminfo"

actor Main
  let env: Env
  let s: String val = "X".mul(400)
  new create(env': Env) =>
    env = env'
    env.out.print(MemInfo.string(s).string())
    Two(this, env)

  be gimmie(two: Two tag) =>
    two.receive(s)




actor Two
  let env: Env
  new create(main: Main tag, env': Env) =>
    env = env'
    env.out.print(MemInfo.actor_self().string())
    main.gimmie(this)
    
  be receive(s: String val) =>
    env.out.print(MemInfo.actor_self().string())
