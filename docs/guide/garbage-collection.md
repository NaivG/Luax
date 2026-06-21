---
title: "Garbage Collection"
description: "Incremental tri-color mark-and-sweep garbage collector compatible with Lua 5.3 semantics"
outline: [2, 3]
library: "guide"
---

# Garbage Collection

Luax ships with an incremental tri-color mark-and-sweep garbage collector
compatible with Lua 5.3 semantics. The collector cooperates with Dart's own
GC — Dart reclaims the underlying memory while the Luax collector tracks
Lua-level reachability, runs `__gc` finalizers, and provides memory
accounting.

## Finalizers (`__gc`)

Attach a finalizer to a table — it'll be called when the table is collected:

```lua
-- Attach a finalizer to a table
local t = setmetatable({}, {__gc = function()
  print("finalized!")
end})
t = nil
collectgarbage("collect")  -- → finalized!
```

Finalizers run at most once, on the GC thread that reclaims the object. They
are useful for releasing native resources (file handles, sockets) that the
Lua state has acquired.

## Weak references

A table with `__mode = "k"` (or `"v"` / `"kv"`) has weak keys (or values,
or both). Entries are removed automatically when the weak side is no longer
referenced from outside the table:

```lua
-- Weak references
local cache = setmetatable({}, {__mode = "v"})
cache[1] = {data = "ephemeral"}
cache[1] = nil
collectgarbage("collect")
-- The cached value is now eligible for collection even if the table itself is alive
```

`__mode` accepts:

| Value | Effect |
|---|---|
| `"k"` | Keys are weak |
| `"v"` | Values are weak |
| `"kv"` | Both keys and values are weak |

Weak tables are commonly used for memoization and for object identity
mappings. See the [Lua 5.3
manual](https://www.lua.org/manual/5.3/manual.html#2.5.2) for the full
semantics.

## `collectgarbage` API

Luax supports the full Lua 5.3 `collectgarbage` function:

| Option | Description |
|---|---|
| `"collect"` | Run a full GC cycle |
| `"stop"` | Stop the incremental collector |
| `"restart"` | Restart the incremental collector |
| `"count"` | Return the current memory usage in KB |
| `"step"` | Step the collector by one unit of work |
| `"setpause"` | Set the pause parameter (returns the new value) |
| `"setstepmul"` | Set the step multiplier (returns the new value) |
| `"isrunning"` | Return `true` if the collector is running |
| `"info"` | Return a structured table with `phase`, `debt`, and totals |

The `info` option is Luax-specific and is useful for telemetry and
profiling:

```lua
local stats = collectgarbage("info")
print(stats.phase, stats.debt)
```

## Pause and step multiplier

The collector is incremental — it does small chunks of work as the VM
allocates. The amount of work is controlled by two parameters:

- **Pause** — the delay between GC cycles. Higher values reduce GC overhead
  but increase peak memory.
- **Step multiplier** — the relative speed of the collector compared to
  allocation. Higher values collect more aggressively.

```lua
collectgarbage("setpause", 200)
collectgarbage("setstepmul", 200)
```

Luax's default values are `200` and `200`, which match the upstream Lua 5.3
defaults. For most applications, the defaults are fine. For latency-sensitive
applications, raising the step multiplier reduces GC pause time at the cost
of slightly more total work.

## Interop with Dart

Luax tracks Lua-level reachability — what tables, closures, threads, and
userdata are still in use from Lua's perspective. The actual byte arrays
backing strings, the closure objects, the upvalue holders, and the thread
state are all allocated as ordinary Dart objects, so Dart's own collector
will reclaim them once Luax releases them.

This means:

- You don't need to call `collectgarbage("collect")` to avoid Dart-side
  leaks — Dart's GC will eventually reclaim anything Luax has stopped
  referencing.
- `collectgarbage` is still useful for triggering `__gc` finalizers at a
  predictable time, or for memory-usage telemetry.

## A telemetry example

```dart
// Dart side — read Lua memory usage from the API
import 'package:luax/lua.dart';

void printMemStats(LuaState ls) {
  // The C-equivalent of collectgarbage("count")
  final kb = ls.gcCount();
  print('Lua-managed memory: $kb KB');
}
```

For lower-level GC internals — the tri-color mark-and-sweep state machine,
debt-based pacing, weak-table finalization — see the
[Architecture deep-dive](../architecture.md).
