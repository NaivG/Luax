# Luax

![Luax Hero](assets/images/hero.png)

---

A pure-Dart implementation of the Lua 5.3 virtual machine — actively maintained, performance-tuned, and feature-complete.

[English](README.md) | [简体中文](README_zh.md)

## About

Luax is a maintained fork of [LuaDardo Plus](https://github.com/ImL1s/LuaDardo) (which was a [LuaDardo](https://github.com/arcticfox1919/LuaDardo) fork) , the original Lua 5.3 VM written in pure Dart.

| Stage | Maintainer | Highlights |
|-------|-----------|------------|
| [LuaDardo](https://github.com/arcticfox1919/LuaDardo) | arcticfox1919 | Original Lua 5.3 VM implementation |
| [LuaDardo Plus](https://github.com/ImL1s/LuaDardo) | ImL1s | Bug fixes (#13, #24, #33, #34, #36), web support, async functions, coroutines |
| [Telosnex fork](https://github.com/Telosnex/LuaDardo) | Telosnex / jpohhhh | goto/label, 40+ bug fixes, major performance work, parser restructure, Lua 5.3 pattern matcher |
| Luax (this repo) | NaivG | Ongoing maintenance and development, bug fixes (#7) |

> [!important]
> Starting from commit [a2576f](https://github.com/NaivG/Luax/commit/a25676f0ad6cfcf0234b4bbda053165ece882b91), Luax will be separated from LuaDardo's fork network for better development.
> But you can still use Luax as a fork of LuaDardo.

## Features

- **100% Dart** — no native dependencies, runs on all Dart platforms including web
- **goto/label** — full Lua 5.2+ scoping rules with proper upvalue closing
- **Lua 5.3 pattern matching** — reference C implementation ported to Dart, including `%b` and `%f`
- **Binary data** — `string.pack`, `string.unpack`, `string.packsize`, and `string.dump`
- **Async interop** — call async Dart functions from Lua and vice versa
- **Exposed parser & AST** — `lua_parser.dart` for static analysis tooling
- **Web platform** — full browser support via platform abstraction layer
- **Performance** — parser ~47% faster, VM stack ~22% faster, sprintf 5x faster than upstream

## Installation

```yaml
dependencies:
  luax:
    git: https://github.com/NaivG/Luax.git
```

```bash
dart pub get
```

## Quick Start

```dart
import 'package:luax/lua.dart';

void main() {
  final state = LuaState.newState();
  state.openLibs();
  state.doString(r'''
    for i = 1, 5 do
      print("Hello from Lua!", i)
    end
  ''');
}
```

## Usage

The API mirrors the [Lua C API](https://www.lua.org/manual/5.3/manual.html#luaL_newstate). If you've used `lua_State` in C, the Dart API will feel familiar.

### Dart Calls Lua

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

### Lua Calls Dart

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

The wrapper function signature is `int Function(LuaState ls)`, where the return value indicates how many values are pushed onto the Lua stack.

### Async Dart Functions

Call async Dart code from Lua — useful for HTTP requests, file I/O, database queries, etc.

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

  // Call it from Dart
  state.getGlobal('fetchData');
  state.pushString('https://api.example.com');
  await state.callAsync(1, 1);
  print(state.toStr(-1));  // Response from https://api.example.com
}
```

**Async API reference:**

| Method | Description |
|--------|-------------|
| `registerAsync(name, func)` | Register an async function as a Lua global |
| `pushDartFunctionAsync(func)` | Push an async function onto the stack |
| `pushDartClosureAsync(func, n)` | Push an async closure with `n` upvalues |
| `callAsync(nArgs, nResults)` | Call a function asynchronously |
| `pCallAsync(nArgs, nResults, err)` | Protected async call with error handler |
| `doStringAsync(code)` | Execute a Lua string asynchronously |
| `doFileAsync(path)` | Execute a Lua file asynchronously |

## Language Features

### goto / label

Full support for Lua 5.2+ `goto` and `::label::` syntax, including proper upvalue closing and same-name label shadowing:

```lua
for i = 1, 10 do
  for j = 1, 10 do
    if i * j > 50 then
      goto done
    end
    print(i, j)
  end
end
::done::
print("Finished!")
```

### Coroutines

Full Lua coroutine library:

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

### Lua 5.3 Pattern Matching

The pattern matcher is ported from the reference Lua 5.3 C implementation, including support for `%b` (balanced match) and `%f` (frontier pattern):

```lua
-- Balanced parentheses matching
print(string.match("(hello (world))", "%b()"))  -- (hello (world))

-- Frontier pattern (word boundaries)
for w in string.gmatch("hello world", "%f[%a]%a+") do
  print(w)  -- "hello", "world"
end
```

### Binary Data Packing

`string.pack`, `string.unpack`, and `string.packsize` for binary data manipulation:

```lua
local packed = string.pack(">i4i4", 100, 200)
local a, b = string.unpack(">i4i4", packed)
print(a, b)  -- 100  200
```

### Function Serialization

`string.dump` serializes compiled Lua functions to binary chunk format:

```lua
local f = load("return 1 + 2")
local bytes = string.dump(f)
local f2 = load(bytes)
print(f2())  -- 3
```

## Parser & Static Analysis

The parser and AST are exposed as a separate library for building static analysis tools:

```dart
import 'package:luax/lua_parser.dart';

void main() {
  final parser = Parser('print("hello")', 'example.lua');
  final block = parser.parse();
  // Inspect the AST: block.stats, expressions, etc.
}
```

A debug utility is also available for inspecting the Lua stack at runtime:

```dart
import 'package:luax/debug.dart';

state.printStack();  // Prints stack contents with types and values
```

## Performance

Significant performance improvements over the upstream LuaDardo Plus v0.3.0:

| Component | Improvement | Notes |
|-----------|------------|-------|
| Parser (end-to-end) | ~47% faster | Lexer + statement parser tuning |
| Statement parser | ~12% faster | Records + pre-sized lists |
| VM stack | ~22% faster | Fixed-capacity array implementation |
| `sprintf` | 5x faster | Optimized fork for Lua formatting |
| `string.format` | 3.7x faster | Bypasses `sprintf` for simple specifiers |
| Opcode dispatch | Reduced overhead | Eliminated stringly-typed dispatch |

## Flutter Integration

For a full example of integrating Luax into a Flutter application with Riverpod state management, see the [Flutter Lua Example](https://github.com/ImL1s/flutter_lua_example).

### Architecture

![Integration Architecture](assets/images/architecture.png)

### Bidirectional Communication Flow

![Communication Flow](assets/images/flow.png)

## Web Platform Support

Luax runs in browsers via a platform abstraction layer that handles `dart:io` dependencies:

```dart
import 'package:luax/lua.dart';
import 'package:luax/src/platform/platform.dart';

void main() {
  // Redirect print output (useful for web)
  PlatformServices.instance.printCallback = (s) => print(s);

  final state = LuaState.newState();
  state.openLibs();
  state.doString('print("Hello from Lua on the web!")');
}
```

**Web limitations:** `os.execute()`, `os.exit()`, `os.remove()`, `os.rename()`, and `os.getenv()` throw `UnsupportedError`. Time functions (`os.time`, `os.clock`, `os.date`, `os.difftime`) work normally. File loading (`doFile`, `loadFile`) is not supported on web.

## Migration from lua_dardo/lua_dardo_plus

Update your dependency and import:

```yaml
# pubspec.yaml
dependencies:
  luax:
    git: https://github.com/NaivG/Luax.git
```

```dart
// Before
import 'package:lua_dardo/lua.dart';

// After
import 'package:luax/lua.dart';
```

Additional imports available:

```dart
import 'package:luax/lua_parser.dart';  // Parser & AST
import 'package:luax/debug.dart';        // Debug utilities
```

## License

Apache-2.0 (same as original LuaDardo)

## Credits

| Contributor | Role |
|-------------|------|
| [arcticfox1919](https://github.com/arcticfox1919) | Original LuaDardo author |
| [ImL1s](https://github.com/ImL1s) | LuaDardo Plus fork — bug fixes, web support, async, coroutines |
| [Telosnex / jpohhhh](https://github.com/Telosnex) | goto/label, performance work, parser restructure, 40+ bug fixes |
| [NaivG](https://github.com/NaivG) | Current maintainer |
