---
title: "Coroutines"
description: "Full Lua 5.3 coroutine library support with async-aware resume"
outline: [2, 3]
library: "guide"
---

# Coroutines

Full Lua 5.3 coroutine library support, plus async-aware resume for
suspending into Dart futures.

## Basic coroutines

```lua
local co = coroutine.create(function(a, b)
  local sum = a + b
  local extra = coroutine.yield(sum)
  return sum + extra
end)

local ok, result = coroutine.resume(co, 10, 20)
print(result)            -- 30 (yielded value)
local ok2, result2 = coroutine.resume(co, 5)
print(result2)           -- 35 (final result)
```

## Wrapping coroutines as iterators

`coroutine.wrap` returns a function that, when called, resumes the coroutine
and returns the next yielded value:

```lua
local iter = coroutine.wrap(function()
  for i = 1, 5 do
    coroutine.yield(i * 2)
  end
end)

for v in iter do
  print(v)  -- 2, 4, 6, 8, 10
end
```

## Async coroutines

`coroutine.resumeAsync` is a Luax extension that lets a coroutine suspend on
async Dart functions (registered with `registerAsync`). Internally the VM
yields until the future completes, then resumes the coroutine with the result.

```dart
// Dart side
state.registerAsync('httpGet', (ls) async {
  final url = ls.checkString(1)!;
  await Future.delayed(Duration(milliseconds: 200));
  ls.pushString('{"status":"ok"}');
  return 1;
});
```

```lua
-- Lua side — `await` requires the call to be inside a coroutine
local co = coroutine.create(function()
  local body = await httpGet("https://api.example.com")
  print("got:", body)
end)
coroutine.resumeAsync(co)
```

See the [Async / Await guide](async-await.md) for the full protocol and
the `await` keyword.

## Coroutine status

`coroutine.status(co)` returns one of:

| Status | Meaning |
|---|---|
| `"running"` | The coroutine that's currently running (the one calling `status`) |
| `"suspended"` | Yielded, waiting for the next `resume` |
| `"normal"` | Active but not the one currently running (only possible across coroutines) |
| `"dead"` | Has finished or errored |

`coroutine.running()` returns the running coroutine plus a boolean indicating
whether it's the main one.

## Yielding from C / Dart

The Dart API exposes
[`LuaCoroutineLib.pushThread`](/api/lua/LuaCoroutineLib#pushthread) and
[`xmove`](/api/lua/LuaCoroutineLib#xmove) for moving values between threads
manually. For most use cases, the Lua-side `coroutine` library is sufficient.
