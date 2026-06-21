---
title: "Async / Await"
description: "Bidirectional async function calls between Dart and Lua"
outline: [2, 3]
library: "guide"
---

# Async / Await

Luax supports bidirectional async function calls between Dart and Lua. Async
Dart functions (HTTP requests, file I/O, database queries) can be invoked from
Lua, and Lua coroutines can suspend until an async operation completes.

## Dart Async API

Call functions (both Dart and Lua) asynchronously from Dart. This is useful for
HTTP requests, file I/O, database queries, and other async operations driven by
Dart code.

```dart
Future<int> fetchData(LuaState ls) async {
  final url = ls.checkString(1);

  // Simulate async operation
  await Future.delayed(Duration(seconds: 1));

  ls.pushString('Response from $url');
  return 1;
}

void main() async {
  final state = LuaState.newState();
  state.openLibs();

  // Register async function as a global
  state.registerAsync('fetchData', fetchData);

  // Call it from Dart using callAsync
  state.getGlobal('fetchData');
  state.pushString('https://api.example.com');
  await state.callAsync(1, 1);
  print(state.toStr(-1));  // Response from https://api.example.com
}
```

## Lua calling async functions

> [!important]
> `await` keyword is a custom keyword in Luax **after 0.3.1**, NOT a part of
> the Lua language.
>
> If you are using an older version of Luax, you can simply use the same
> syntax as sync functions.

When Lua code calls an async-registered Dart function, it must use the `await`
keyword or be running inside a coroutine (via `coroutine.create` and
`coroutine.resumeAsync`).

```lua
-- `await` is a reserved keyword in Luax
local result = await fetchData("https://api.example.com")
print(result)

-- Nested await
local a = await fetchData("url1")
local b = await fetchData("url2")

-- Coroutine
local co = coroutine.create(function()
  local a = fetchData("url1")
end)
coroutine.resumeAsync(co)
```

> **Note:** `await` can only appear before a function call expression. Using it
> as a variable name or in any other identifier position is a syntax error.

If an async function is called from Lua without `await` or outside a coroutine,
the call will fail and returns `(nil, error_string)`:

```lua
local r, err = asyncFunc()
-- r   = nil
-- err = "attempt to call async function `asyncFunc` without await or in non-async context"
```

## Async API Reference

| Method | Description |
|--------|-------------|
| `registerAsync(name, func)` | Register an async function as a Lua global |
| `pushDartFunctionAsync(func)` | Push an async function onto the stack |
| `pushDartClosureAsync(func, n)` | Push an async closure with `n` upvalues |
| `callAsync(nArgs, nResults)` | Call a function asynchronously |
| `pCallAsync(nArgs, nResults, err)` | Protected async call with error handler |
| `doStringAsync(code)` | Execute a Lua string asynchronously |
| `doFileAsync(path)` | Execute a Lua file asynchronously |

See [`LuaBasicAPI`](/api/lua/LuaBasicAPI) for the full method list.

## A full async example

```dart
import 'dart:async';
import 'package:luax/lua.dart';

Future<int> httpGet(LuaState ls) async {
  final url = ls.checkString(1)!;
  await Future.delayed(Duration(milliseconds: 200));  // simulate I/O
  ls.pushString('{"status":"ok","url":"$url"}');
  return 1;
}

void main() async {
  final state = LuaState.newState();
  state.openLibs();
  state.registerAsync('httpGet', httpGet);

  // Drive the VM from Dart using await
  await state.doStringAsync(r'''
    local co = coroutine.create(function()
      local body = await httpGet("https://api.example.com/users")
      print("got:", body)
    end)
    coroutine.resumeAsync(co)
  ''');
}
```

For the full protocol — including `coroutine.resumeAsync`, error propagation
across the boundary, and combining `await` with regular Lua control flow — see
the [Coroutines guide](coroutines.md).
