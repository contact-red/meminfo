primitive FlatMem
  fun alloc(a: FlatMemType): USize => a._2
  fun logical(a: FlatMemType): USize => a._3

primitive StringMem
  fun s_alloc(a: StringMemType): USize => a._2
  fun s_logical(a: StringMemType): USize => a._3
  fun p_alloc(a: StringMemType): USize => a._4
  fun s_reserved(a: StringMemType): USize => a._5
  fun s_size(a: StringMemType): USize => a._6

primitive ArrayMem
  fun s_alloc(a: ArrayMemType): USize => a._2
  fun s_logical(a: ArrayMemType): USize => a._3
  fun p_alloc(a: ArrayMemType): USize => a._4
  fun a_reserved(a: ArrayMemType): USize => a._5
  fun a_count(a: ArrayMemType): USize => a._6
  fun e_size(a: ArrayMemType): USize => a._7






type FlatMemType is (FlatMem, USize, USize)
type StringMemType is (StringMem, USize, USize, USize, USize, USize)
type ArrayMemType is (ArrayMem, USize, USize, USize, USize, USize, USize)
