use "collections"
use "../../meminfo"

actor Main
  let env: Env
  new create(env': Env) =>
    env = env'
    env.out.print(MemInfo.actor_self().string()) // Stack

    let s: String trn = recover trn String end
    for f in Range[USize](0, 100) do
      s.push('x')
      env.out.print(s.cpointer().usize().string() + ": " + MemInfo.string(s).string())
    end


    let t: String trn = recover trn String(193) end
    env.out.print(t.cpointer().usize().string() + ": " + MemInfo.string(t).string())

