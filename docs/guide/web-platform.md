---
title: "Web Platform"
description: "Running Luax in browsers via the platform abstraction layer"
outline: [2, 3]
library: "guide"
---

# Web Platform

Luax runs in browsers via a platform abstraction layer that handles
`dart:io` dependencies. When you compile for the web, the platform service is
swapped to a web implementation that stubs out everything that doesn't make
sense in a browser.

## Basic setup

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

`print` in Lua routes through `PlatformServices.instance.printCallback`,
which defaults to a `print`-based sink on native and to a console sink on
the web. Override it to capture output for display in a UI.

## Web limitations

The following APIs throw `UnsupportedError` on the web:

| API | Status on web | Reason |
|---|---|---|
| `os.execute()` | Throws | No process spawning |
| `os.exit()` | Throws | No process control |
| `os.remove()` | Throws | No filesystem write access |
| `os.rename()` | Throws | No filesystem write access |
| `os.getenv()` | Throws | No environment access |
| `os.tmpname()` | Throws | No filesystem access |
| `io.*` (full library) | Limited | No native filesystem |
| `doFile` / `loadFile` | Throws | No native filesystem |
| `package.*` | Limited | No `require` semantics for the filesystem |

Time functions work normally:

| API | Status on web |
|---|---|
| `os.time()` | ✅ Works |
| `os.clock()` | ✅ Works (uses `DateTime.now()`) |
| `os.date()` | ✅ Works |
| `os.difftime()` | ✅ Works |

Most of the standard libraries — `string`, `math`, `table`, `coroutine`,
`utf8`, `event` — work without changes. The `os` library is partially
available as listed above.

## Loading Lua source on the web

`doFile` and `loadFile` are file-system based, so they don't work on the
web. Instead, fetch the source as text and use `doString` / `loadString`:

```dart
import 'dart:html';  // or package:web for js interop

Future<void> runScript(String url, LuaState state) async {
  final response = await HttpRequest.getString(url);
  state.doString(response);
}
```

For `package:web` / `dart:js_interop` based code, the equivalent is
`http.get` or a manual `XMLHttpRequest`/`fetch` call wrapped in a
`Future<String>`.

## `dart:js_interop` for browser APIs

The web platform implementation uses `dart:js_interop` under the hood. If you
need to expose browser APIs to Lua, use the standard
`package:web` / `dart:js_interop` mechanisms:

```dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS()
external web.Window get _window;  // bound to window in JS

void registerBrowserGlobals(LuaState ls) {
  // expose `window.console.log` to Lua as `log`
  // ... Lua binding boilerplate ...
}
```

## Performance on the web

Lua execution on the web runs entirely in JavaScript. Luax's register-based
VM is fast enough for typical scripting workloads (config, UI logic, game
scripts), but you'll see slower numeric-heavy code compared to native
execution. For benchmarks, see the [Architecture deep-dive](../architecture.md).
