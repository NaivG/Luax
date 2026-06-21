---
title: "Migrating from lua_dardo / lua_dardo_plus"
description: "Drop-in replacement notes for users coming from lua_dardo or lua_dardo_plus"
outline: [2, 3]
library: "migration"
---

# Migrating from lua_dardo / lua_dardo_plus

If you're coming from `lua_dardo` or `lua_dardo_plus`, Luax is a drop-in
replacement. The API surface is the same Lua C API mirror that those
projects exposed, plus a number of Luax-specific extensions covered in the
[Guide](../guide/).

## Update your dependency

```yaml
# pubspec.yaml
dependencies:
  luax:
    git: https://github.com/NaivG/Luax.git
```

Remove the old `lua_dardo` / `lua_dardo_plus` entry and run:

```bash
dart pub get
```

## Update your imports

```dart
// Before
import 'package:lua_dardo/lua.dart';

// After
import 'package:luax/lua.dart';
```

The package-prefixed import paths are the only thing that needs to change.
The `LuaState` and the rest of the API are identical.

## Additional imports available

Luax exposes two extra entry points that aren't in the upstream LuaDardo
lineage:

```dart
import 'package:luax/lua_parser.dart';  // Parser & AST
import 'package:luax/debug.dart';        // Debug utilities
```

`lua_parser` gives you the parser and AST as a separate library — useful for
building static analysis tools. `debug` adds the `LuaStateDebug` extension
with `printStack()` and other stack-inspection helpers.

## What stays the same

Everything in the Lua 5.3 surface — integers, bitwise operators, the `//`
integer division, `goto` / `::label::`, `string.pack` / `unpack`, UTF-8
support, the full standard library. The basic VM control flow
(`LuaState.newState`, `openLibs`, `doString`, `doFile`, `load`, `call`,
`pCall`, `getTop`, `push*` / `pop*` / `getField` / `setField` / `getGlobal`
/ `setGlobal`) is unchanged.

## What's new in Luax

A few APIs that didn't exist in the upstream LuaDardo lineage:

- **Async / await** — `registerAsync`, `pushDartFunctionAsync`,
  `pushDartClosureAsync`, `callAsync`, `pCallAsync`, `doStringAsync`,
  `doFileAsync`. Plus the `await` keyword in Lua when calling async Dart
  functions. See the [Async / Await guide](../guide/async-await.md).
- **Event system** — `LuaEventAPI` on the Dart side, `event.on/once/off/emit/emitAsync`
  on the Lua side. See the [Event System guide](../guide/event-system.md).
- **Exposed parser & AST** — `lua_parser` library, with the `Block` /
  `Exp` / `Stat` / `Node` types and all concrete subclasses public. See the
  [Parser & AST guide](../guide/parser-ast.md).
- **Web platform support** — runs in the browser via a platform abstraction
  layer. See the [Web Platform guide](../guide/web-platform.md).
- **Garbage collector metrics** — the `collectgarbage("info")` option
  returns a structured table with phase, debt, and totals. See the
  [Garbage Collection guide](../guide/garbage-collection.md).
- **`coroutine.resumeAsync`** — async counterpart of `coroutine.resume`.
  See the [Coroutines guide](../guide/coroutines.md).

If you were on `lua_dardo_plus` (rather than plain `lua_dardo`), you
already had async and web support — the Luax versions are stricter
backwards-compatible supersets.

## Performance

Luax is meaningfully faster than `lua_dardo_plus v0.3.0` on most paths:

| Component | Improvement | Notes |
|-----------|------------|-------|
| Parser (end-to-end) | ~47% faster | Lexer + statement parser tuning |
| Statement parser | ~12% faster | Records + pre-sized lists |
| VM stack | ~22% faster | Fixed-capacity array implementation |
| GC tri-color | Integer-backed | Per-object memory overhead reduced |
| GC hot paths | Cached `__gc` / `__mode` | Eliminates repeated hash lookups |
| `sprintf` | 5x faster | Optimized fork for Lua formatting |
| `string.format` | 3.7x faster | Bypasses `sprintf` for simple specifiers |
| Opcode dispatch | Reduced overhead | Eliminated stringly-typed dispatch |

For a deeper look at the optimizations, see the
[Architecture deep-dive](../architecture.md).
