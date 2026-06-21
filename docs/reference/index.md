---
title: "Reference"
description: "Public Dart API and standard libraries shipped with the Luax VM"
outline: [2, 3]
---

# Reference

The Luax reference section covers the public Dart API and the standard
libraries that ship with the VM.

## Contents

<div grid="cols-2" gap="16">

- ### [API Reference](api.md)

  The auto-generated API reference, organized by library entry point.
  Generated from `///` dartdoc comments — this is the authoritative Dart API
  surface.

- ### [Standard Library](standard-library.md)

  The Lua-side standard libraries that `state.openLibs()` loads: `print`,
  `assert`, `error`, `ipairs`, `pairs`, `select`, `collectgarbage`, and the
  full `string` / `math` / `table` / `os` / `package` / `coroutine` / `utf8`
  / `event` libraries.

</div>

## What's where

The Luax package exposes three top-level Dart entry points:

| Entry point | Use it for |
|---|---|
| `package:luax/lua.dart` | The main runtime API — `LuaState`, stack ops, async, events, coroutines, debug, platform |
| `package:luax/lua_parser.dart` | Parsing Lua source into an AST for static analysis |
| `package:luax/debug.dart` | Debugging utilities (e.g. `LuaState.printStack()`) |

For Flutter-specific APIs (widget bindings, `LuaxScriptLoader`), see
[`flutter_luax`](https://github.com/NaivG/flutter_luax) — that's a separate
package.
