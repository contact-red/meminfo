use @mi_ts_inc[None](name: Pointer[U8] tag, len: USize)
use @mi_ts_dec[None](name: Pointer[U8] tag, len: USize)
use @mi_ts_get[I64](name: Pointer[U8] tag, len: USize)
use @mi_ts_count[USize]()
use @mi_ts_snapshot[USize](names: Pointer[Pointer[U8]] tag,
  lens: Pointer[USize] tag, counts: Pointer[I64] tag, max: USize)

primitive TypeStats
  """
  Track live instance counts by name. Call `inc` in constructors and `dec` in
  `_final` to maintain a running count of how many instances of each tracked
  type are alive. A statistics actor reads the counts via `get` or `snapshot`.

  Pass `__loc.type_name()` as the name to use the enclosing type's name
  automatically. The typical usage is one line per constructor and one per
  `_final`:

  ```pony
  actor MyActor
    new create() =>
      TypeStats.inc(__loc.type_name())

    fun _final() =>
      TypeStats.dec(__loc.type_name())
  ```

  Pass a custom string to group instances under a shared key:

  ```pony
  TypeStats.inc("workers")
  ```
  """

  fun inc(name: String val) =>
    """
    Increment the live count for `name`.
    """
    @mi_ts_inc(name.cpointer(), name.size())

  fun dec(name: String val) =>
    """
    Decrement the live count for `name`.
    """
    @mi_ts_dec(name.cpointer(), name.size())

  fun get(name: String val): I64 =>
    """
    Current live count for `name`. Returns 0 if `name` has never been tracked.
    """
    @mi_ts_get(name.cpointer(), name.size())

  fun tracked_count(): USize =>
    """
    Number of distinct names currently tracked.
    """
    @mi_ts_count()

  fun snapshot(): Array[(String val, I64)] val =>
    """
    A point-in-time copy of all tracked names and their counts.
    """
    let n = @mi_ts_count()
    if n == 0 then return recover val Array[(String val, I64)] end end
    recover val
      let names = Array[Pointer[U8]].init(Pointer[U8], n)
      let lens = Array[USize].init(0, n)
      let counts = Array[I64].init(0, n)
      let actual = @mi_ts_snapshot(names.cpointer(), lens.cpointer(),
        counts.cpointer(), n)
      let result = Array[(String val, I64)](actual)
      var i: USize = 0
      while i < actual do
        try
          let p = names(i)?
          let l = lens(i)?
          let c = counts(i)?
          result.push((String.from_cpointer(p, l).clone(), c))
        end
        i = i + 1
      end
      result
    end
