use "../../meminfo"

class Worker
  new create() =>
    TypeStats.inc(__loc.type_name())

  fun _final() =>
    TypeStats.dec(__loc.type_name())

class Connection
  new create() =>
    TypeStats.inc(__loc.type_name())

  fun _final() =>
    TypeStats.dec(__loc.type_name())

actor Main
  new create(env: Env) =>
    let w1 = Worker
    let w2 = Worker
    let w3 = Worker
    let c1 = Connection
    let c2 = Connection

    env.out.print("--- Live counts ---")
    env.out.print("Worker:     " + TypeStats.get("Worker").string())
    env.out.print("Connection: " + TypeStats.get("Connection").string())

    env.out.print("\n--- Snapshot ---")
    for (name, count) in TypeStats.snapshot().values() do
      env.out.print(name + ": " + count.string())
    end
