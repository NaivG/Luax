---
title: "Dart ↔ Lua Interop"
description: "Dart API for interacting with the Lua VM — mirrors the Lua C API"
outline: [2, 3]
library: "guide"
---

# Dart ↔ Lua Interop

The API mirrors the [Lua C
API](https://www.lua.org/manual/5.3/manual.html#luaL_newstate). If you've used
`lua_State` in C, the Dart API will feel familiar.

## Dart Calls Lua

Read Lua variables from Dart:

```lua
-- config.lua
width = 1920
height = 1080
title = "My App"
```

```dart
final ls = LuaState.newState();
ls.openLibs();
ls.doFile("config.lua");

ls.getGlobal("width");
print("width = ${ls.toInteger(-1)}");  // 1920
ls.pop(1);

ls.getGlobal("title");
print("title = ${ls.toStr(-1)}");  // My App
ls.pop(1);
```

Call Lua functions with arguments and return values:

```lua
-- math_utils.lua
function add(a, b)
    return a + b
end
```

```dart
ls.doFile("math_utils.lua");
ls.getGlobal("add");
ls.pushInteger(3);
ls.pushInteger(4);
ls.pCall(2, 1, 0);
print("3 + 4 = ${ls.toInteger(-1)}");  // 7
```

Read Lua tables:

```lua
-- config.lua
player = { name = "Hero", hp = 100, level = 5 }
```

```dart
ls.getGlobal("player");
ls.getField(-1, "name");
print(ls.toStr(-1));  // Hero
ls.pop(1);
ls.getField(-1, "hp");
print(ls.toInteger(-1));  // 100
ls.pop(2);  // pop hp + table
```

## Lua Calls Dart

Register Dart functions that Lua scripts can invoke:

```dart
import 'dart:math';

int dartRandom(LuaState ls) {
  final max = ls.checkInteger(1);
  ls.pop(1);
  ls.pushInteger(Random().nextInt(max));
  return 1;  // number of return values
}

void main() {
  final state = LuaState.newState();
  state.openLibs();

  state.pushDartFunction(dartRandom);
  state.setGlobal('dartRandom');

  state.doString('''
    print("Random:", dartRandom(100))
  ''');
}
```

The wrapper function signature is `int Function(LuaState ls)`, where the
return value indicates how many values are pushed onto the Lua stack.

## Reading stack values

After a call, results live on the stack. Use the type checks and conversions to
read them:

```dart
ls.pCall(nArgs, nResults, 0);  // 0 = no message handler

for (var i = -nResults; i <= 0; i++) {
  if (ls.isInteger(i)) {
    print('int: ${ls.toInteger(i)}');
  } else if (ls.isString(i)) {
    print('string: ${ls.toStr(i)}');
  } else if (ls.isBoolean(i)) {
    print('bool: ${ls.toBoolean(i)}');
  } else if (ls.isNil(i)) {
    print('nil');
  } else if (ls.isTable(i)) {
    print('table');
  }
}
```

See the full type-check and conversion API in
[`LuaBasicAPI`](/api/lua/LuaBasicAPI).

## Error handling

Prefer `pCall` over `call` for any Lua code that might raise. `pCall` traps
errors and pushes a result code; `call` lets them propagate as Dart exceptions:

```dart
ls.getGlobal('mightFail');
ls.pushString('input');
final result = ls.pCall(1, -1, 0);  // -1 = luaMultRet (keep all results)
if (result != ThreadStatus.luaOk) {
  // An error occurred. The error message is on the stack.
  final err = ls.toStr(-1);
  ls.pop(1);
  print('Lua error: $err');
}
```

For long-lived VMs you may want to install a panic handler with `atpanic` —
see the [Lua C API
docs](https://www.lua.org/manual/5.3/manual.html#lua_atpanic) for the
convention.
