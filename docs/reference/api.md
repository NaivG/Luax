---
title: "API Reference"
description: "Auto-generated API documentation for the Luax Dart API"
outline: [2, 3]
library: "reference"
---

# API Reference

The Luax API reference is **auto-generated** from the `///` dartdoc comments
in the source code by [`dartdoc_modern`](https://github.com/777genius/dartdoc_modern).
The generated site lives under `/api/`.

This page is a quick index into the generated reference, organized by the
top-level entry points you can `import` in Dart.

## Library entry points

| Entry point | Generated page | What's in it |
|---|---|---|
| `package:luax/lua.dart` | [`/api/lua/`](/api/lua/) | The main runtime API — `LuaState`, `LuaBasicAPI`, `LuaAuxLib`, `LuaCoroutineLib`, `LuaDebug`, `LuaEventAPI`, `PlatformServices`, enums, typedefs |
| `package:luax/lua_parser.dart` | [`/api/lua_parser/`](/api/lua_parser/) | Parser & AST types for static analysis — `Parser`, `Block`, `Exp`, `Stat`, `Node` and all concrete subclasses |
| `package:luax/debug.dart` | [`/api/debug/`](/api/debug/) | Debug utilities — `LuaStateDebug` extension |
| `package:flutter_luax/flutter_lua.dart` | _(external)_ | Companion package for Flutter widget bindings — see [Flutter Integration](/guide/flutter-integration.md) |

## Top-level API surface

The most common types you'll reach for:

- [`LuaState`](/api/lua/LuaState) — the abstract VM API
- [`LuaBasicAPI`](/api/lua/LuaBasicAPI) — the C-API-shaped stack operations
- [`LuaAuxLib`](/api/lua/LuaAuxLib) — auxiliary library helpers (load, error reporting, type checks)
- [`LuaCoroutineLib`](/api/lua/LuaCoroutineLib) — coroutine control
- [`LuaEventAPI`](/api/lua/LuaEventAPI) — the Dart side of the event system
- [`LuaDebug`](/api/lua/LuaDebug) — debug hooks
- [`Parser`](/api/lua_parser/Parser) — the Lua source parser
- [`Block`](/api/lua_parser/Block) — the AST root

For conceptual overviews of how these types fit together, see the
[Guide](../guide/) — particularly [Dart↔Lua Interop](../guide/dart-lua-interop.md),
[Async / Await](../guide/async-await.md), and the
[Architecture deep-dive](../guide/architecture.md).

## Note on `///` comments

The auto-generation reads `///` doc comments from the source. If you find a
gap in the reference — a method with no description, a missing parameter
doc — the fix is to add `///` comments in the corresponding `.dart` file and
re-run the generator. The reference is only as good as the comments in the
source.
