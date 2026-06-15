# Luax

![Luax Hero](assets/images/hero.png)

---

A pure-Dart implementation of the Lua 5.3 virtual machine — actively maintained, performance-tuned, and feature-complete.

English | [简体中文](README_zh.md)

## About

Luax is a pure-Dart Lua 5.3 virtual machine, originally derived from [LuaDardo Plus](https://github.com/ImL1s/LuaDardo) (which is a [LuaDardo](https://github.com/arcticfox1919/LuaDardo) fork), and now maintained as an independent project. But you can still use Luax as a fork of LuaDardo.

## Features

- **100% Dart** — no native dependencies, runs on all Dart platforms including web
- **Garbage collection** — incremental tri-color mark-and-sweep collector with `__gc` finalizers, weak tables (`__mode`), and the full `collectgarbage()` API
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

### Async Function Calls

Luax supports bidirectional async function calls between Dart and Lua.

#### Dart Async API

Call functions (both Dart and Lua) asynchronously from Dart. This is useful for HTTP requests, file I/O, database queries, and other async operations driven by Dart code.

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

#### Lua Calling Async Functions

> [!important]
> `await` keyword is a custom keyword in Luax **after 0.3.1**, NOT a part of the Lua language.
> 
> If you are using an older version of Luax, you can simply use the same syntax as sync functions.

When Lua code calls an async-registered Dart function, it must use the `await` keyword or be running inside a coroutine (via `coroutine.create` and `coroutine.resumeAsync`).

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

> **Note:** `await` can only appear before a function call expression. Using it as a variable name or in any other identifier position is a syntax error.

If an async function is called from Lua without `await` or outside a coroutine, the call will failed and returns `(nil, error_string)`:

```lua
local r, err = asyncFunc()
-- r   = nil
-- err = "attempt to call async function `asyncFunc` without await or in non-async context"
```

#### Async API Reference

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

## Garbage Collection

Luax ships with an incremental tri-color mark-and-sweep garbage collector compatible with Lua 5.3 semantics. The collector cooperates with Dart's own GC — Dart reclaims the underlying memory while the Luax collector tracks Lua-level reachability, runs `__gc` finalizers, and provides memory accounting.

```lua
-- Attach a finalizer to a table
local t = setmetatable({}, {__gc = function()
  print("finalized!")
end})
t = nil
collectgarbage("collect")  -- → finalized!

-- Weak references
local cache = setmetatable({}, {__mode = "v"})
cache[1] = {data = "ephemeral"}
cache[1] = nil
collectgarbage("collect")
-- The cached value is now eligible for collection even if the table itself is alive
```

**`collectgarbage` options:** `"collect"`, `"stop"`, `"restart"`, `"count"` (returns KB), `"step"`, `"setpause"`, `"setstepmul"`, `"isrunning"`, `"info"` (returns a structured table with phase, debt, and totals).

## Performance

Significant performance improvements over the upstream LuaDardo Plus v0.3.0:

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

## Flutter Integration

For Flutter apps, Luax provides a companion widget bindings package, [`flutter_luax`](https://github.com/NaivG/flutter_luax), which lets Lua scripts construct widgets like `Scaffold`, `AppBar`, `Container`, `ElevatedButton`, `ListView`, and more.

It also includes a `LuaxScriptLoader` for fetching `.lua` files from a URL or Flutter asset bundle — useful when you want to push UI updates without rebuilding the app.

```yaml
dependencies:
  luax:
    git: https://github.com/NaivG/Luax.git
  flutter_luax:
    git: https://github.com/NaivG/flutter_luax.git
```

See the [flutter_luax README](https://github.com/NaivG/flutter_luax/README.md) for the full widget list
and usage examples. 

A complete integration example with Riverpod state
management is also available at [flutter_lua_example](https://github.com/ImL1s/flutter_lua_example).

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
