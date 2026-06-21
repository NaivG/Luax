---
title: "Getting Started"
description: "Install Luax and run your first Lua program from Dart"
outline: [2, 3]
---

# Getting Started

This guide walks you through installing Luax and running your first Lua
program from Dart. It assumes you have a working Dart SDK (>= 3.0.0) and a
basic familiarity with Lua syntax.

## Installation

Add Luax to your `pubspec.yaml`:

```yaml
dependencies:
  luax:
    git: https://github.com/NaivG/Luax.git
```

Then fetch the package:

```bash
dart pub get
```

Luax has no native dependencies — just one runtime dependency on
[`dart_sprintf`](https://github.com/NaivG/dart-sprintf) (pulled in via git).
It runs on every Dart platform: native (VM), the Dart web compiler
(`dart compile js`), Flutter, and Dart-on-servers.

## Your first Lua program

```dart
import 'package:luax/lua.dart';

void main() {
  final state = LuaState.newState();
  state.openLibs();
  state.doString(r'''
    for i = 1, 5 do
      print("Hello from Luax!", i)
    end
  ''');
}
```

Output:

```
Hello from Luax!	1
Hello from Luax!	2
Hello from Luax!	3
Hello from Luax!	4
Hello from Luax!	5
```

Three things to notice:

1. **`LuaState.newState()`** creates a fresh VM. The returned object is the
   main thread; coroutines are derived from it.
2. **`state.openLibs()`** loads the standard libraries (`print`, `math`,
   `string`, `table`, `os`, `package`, `coroutine`, `utf8`, `event`, ...).
   Skip this call to start with a sandboxed environment.
3. **`state.doString('''...''')`** parses, compiles, and runs the snippet in a
   single step. For larger programs, see [`load`](/api/lua/LuaState#load) and
   [`loadFile`](/api/lua/LuaAuxLib#loadfile).

The API mirrors the [Lua C
API](https://www.lua.org/manual/5.3/manual.html#luaL_newstate) — if you've
written `lua_State` code in C, the Dart API will feel familiar.

## Loading a `.lua` file

```dart
final ls = LuaState.newState();
ls.openLibs();
ls.doFile('config.lua');
```

`doFile` resolves paths against the current working directory. On the web,
`doFile` is not available — use `loadString` with the file contents fetched
ahead of time.

## Calling Dart from Lua

The whole point of an embeddable VM is letting Lua scripts call back into the
host application. Register a Dart function and Lua can invoke it by name:

```dart
import 'dart:math';
import 'package:luax/lua.dart';

int dartRandom(LuaState ls) {
  final max = ls.checkInteger(1);
  ls.pop(1);
  ls.pushInteger(Random().nextInt(max));
  return 1;  // number of values pushed onto the stack
}

void main() {
  final state = LuaState.newState();
  state.openLibs();

  state.pushDartFunction(dartRandom);
  state.setGlobal('dartRandom');

  state.doString('print("Random:", dartRandom(100))');
}
```

The wrapper signature is `int Function(LuaState ls)`. The return value is the
number of values you pushed onto the stack.

## Calling Lua from Dart

```lua
-- math_utils.lua
function add(a, b)
    return a + b
end
```

```dart
ls.doFile('math_utils.lua');
ls.getGlobal('add');
ls.pushInteger(3);
ls.pushInteger(4);
ls.pCall(2, 1, 0);  // 2 args, 1 result, no message handler
print('3 + 4 = ${ls.toInteger(-1)}');  // 7
```

See the [Dart↔Lua Interop guide](guide/dart-lua-interop.md) for the full
push/check/call conventions, error handling with `pCall`, and reading Lua
tables and functions from Dart.

## Next steps

- [Dart↔Lua Interop](guide/dart-lua-interop.md) — the full stack protocol
- [Async / Await](guide/async-await.md) — call async Dart functions from Lua
- [Event System](guide/event-system.md) — bidirectional events between Dart and Lua
- [Architecture](architecture.md) — how the Luax VM works internally
- [API Reference](/api/) — auto-generated from `///` dartdoc comments
