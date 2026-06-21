---
layout: home
hero:
  name: "Luax"
  text: "Pure-Dart Lua 5.3 VM"
  tagline: "Embeddable, async-ready, with web and Flutter support. Maintained since the LuaDardo lineage."
  actions:
    - theme: brand
      text: "Get Started"
      link: "/guide/getting-started/"
    - theme: alt
      text: "API Reference"
      link: "/api/lua/"
    - theme: alt
      text: "GitHub"
      link: "https://github.com/NaivG/Luax"
features:
  - icon: 🧹
    title: Full Garbage Collection
    details: Incremental tri-color mark-and-sweep with __gc finalizers, weak tables, and the standard collectgarbage() API.
  - icon: ⏱️
    title: Async / Await
    details: Call async Dart functions from Lua with the await keyword, or suspend in coroutines via coroutine.resumeAsync.
  - icon: 📡
    title: Event System
    details: Bidirectional EventEmitter bridging Dart and Lua callbacks with one-shot, async, and per-listener unsubscribe.
  - icon: 🧵
    title: Coroutines
    details: Full Lua 5.3 coroutine library — create, yield, resume, wrap — with async resume support.
  - icon: 🔤
    title: Pattern Matching
    details: Reference Lua 5.3 pattern matcher ported to Dart, including %b (balanced) and %f (frontier) patterns.
  - icon: 📦
    title: Binary Data
    details: string.pack / unpack / packsize, plus string.dump for function serialization.
  - icon: 🌐
    title: Web & Flutter
    details: Runs in browsers via a platform abstraction layer; companion flutter_luax package for widget bindings.
  - icon: 🛠️
    title: Exposed Parser & AST
    details: Build static analysis tools on top of lua_parser — Block, Exp, Stat, Node all public.
---

## Install

```yaml
# pubspec.yaml
dependencies:
  luax:
    git: https://github.com/NaivG/Luax.git
```

```bash
dart pub get
```

## Quick Example

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

## Why Luax?

- **100% Dart** — no native dependencies, runs on all Dart platforms including web
- **Lua 5.3 compliant** — full language surface, including `goto`/`label`, integers, bitwise ops, and pattern matching
- **Garbage-collected** — incremental tri-color mark-and-sweep, `__gc` finalizers, weak tables
- **Async interop** — call async Dart functions from Lua with `await`, or use `coroutine.resumeAsync`
- **Event system** — bidirectional EventEmitter bridging Dart and Lua callbacks
- **Web-ready** — runs in the browser via a platform abstraction layer
- **Flutter-ready** — companion [`flutter_luax`](https://github.com/NaivG/flutter_luax) package for widget bindings

Ready to dive in? Start with the [Getting Started guide](/guide/getting-started.md).
