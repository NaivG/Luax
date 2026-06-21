# Luax

![Luax Hero](assets/images/hero.png)

A pure-Dart implementation of the Lua 5.3 virtual machine — actively maintained, performance-tuned, and feature-complete.

English | [简体中文](README_zh.md)

## About

Luax is a pure-Dart Lua 5.3 virtual machine, originally derived from
[LuaDardo Plus](https://github.com/ImL1s/LuaDardo) (which is a
[LuaDardo](https://github.com/arcticfox1919/LuaDardo) fork), and now
maintained as an independent project. But you can still use Luax as a fork
of LuaDardo.

For the full documentation — guides, API reference, and the architecture
deep-dive — see the
[Luax documentation site](https://luax.naivg.top/).

## Features

- **100% Dart** — no native dependencies, runs on all Dart platforms including web
- **Garbage collection** — incremental tri-color mark-and-sweep collector with `__gc` finalizers, weak tables, and the full `collectgarbage()` API
- **Async / await** — call async Dart functions from Lua with the `await` keyword, or suspend in coroutines via `coroutine.resumeAsync`
- **Event system** — bidirectional EventEmitter bridging Dart and Lua callbacks
- **Exposed parser & AST** — `lua_parser.dart` for static analysis tooling
- **Lua 5.3 pattern matching** — `%b` and `%f` patterns, plus the full reference C port
- **Binary data** — `string.pack`, `string.unpack`, `string.packsize`, and `string.dump`
- **Flutter Extension** — companion [`flutter_luax`](https://github.com/NaivG/flutter_luax) package for Flutter widget bindings

See the [Features guide](https://luax.naivg.top/guide/) for the full
list and deeper coverage.

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

## Documentation

Full documentation lives at **[luax.naivg.top](https://luax.naivg.top/)**:

- [Getting Started](https://luax.naivg.top/guide/guide/getting-started) — installation, first program, calling Dart from Lua
- [Guide](https://luax.naivg.top/guide/guide/) — Dart↔Lua interop, async/await, event system, coroutines, GC, web, Flutter
- [API Reference](https://luax.naivg.top/api/lua/) — auto-generated from `///` dartdoc comments
- [Standard Library](https://luax.naivg.top/guide/reference/standard-library) — `string`, `math`, `table`, `os`, `coroutine`, `utf8`, and more
- [Migration from `lua_dardo`](https://luax.naivg.top/guide/migration/from-luadardo) — drop-in replacement notes

## License

Apache-2.0 (same as the original LuaDardo), see [LICENSE](LICENSE).

## Credits

| Contributor | Role |
|-------------|------|
| [arcticfox1919](https://github.com/arcticfox1919) | Original LuaDardo author |
| [ImL1s](https://github.com/ImL1s) | LuaDardo Plus fork — bug fixes, web support, async, coroutines |
| [Telosnex / jpohhhh](https://github.com/Telosnex) | goto/label, performance work, parser restructure, 40+ bug fixes |
| [NaivG](https://github.com/NaivG) | Current maintainer |
