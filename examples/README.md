# Examples

Each subdirectory is a self-contained Pony program demonstrating a different part of the meminfo library.

## [push_string](push_string/)

Pushes bytes onto a `String` one at a time and prints the allocation, reserved space, and used size after each push. Shows how `StringMem` exposes the backing-buffer geometry and how Pony's allocator grows the buffer in size classes.

## [tuple_array](tuple_array/)

Creates an `Array` of tuples, pushes an element, and prints the per-element size, reserved capacity, and count before and after. Demonstrates `ArrayMem` on a compound element type.

## [cross-actor](cross-actor/)

Allocates a `String` in one actor, sends it to another, and prints `StringMem` stats from both sides. Shows that meminfo reads are local to the actor whose heap holds the object.

## [type_stats](type_stats/)

Creates several `Worker` and `Connection` instances, each calling `TypeStats.inc` in its constructor and `TypeStats.dec` in `_final`. Prints per-type live counts and a full snapshot. Demonstrates the `TypeStats` API for tracking live instance counts via `__loc.type_name()`.
