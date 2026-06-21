---
sidebar_position: 0
title: "Luax Documentation"
description: "Pure-Dart Lua 5.3 VM — guides, API reference, and architecture deep-dive"
outline: [2, 3]
---

# Luax Documentation

Welcome to the Luax documentation. Luax is a pure-Dart implementation of the
Lua 5.3 virtual machine, with a garbage collector, async/await interop, an event
system, exposed parser & AST, and full web platform support.

## Where to next?

<div grid="cols-2" gap="16">

- ### [Getting Started](getting-started.md)

  Install Luax, write your first Lua-in-Dart program, and run it on desktop,
  web, or Flutter.

- ### [Guide](guide/)

  Task-oriented guides covering Dart↔Lua interop, async/await, the event
  system, coroutines, garbage collection, the parser/AST, web and Flutter
  integration, and the full Luax architecture deep-dive.

- ### [Reference](guide/reference/)

  API reference (auto-generated from `///` dartdoc comments) and the standard
  library manual.

- ### [Migration](guide/migration/)

  Migrate from `lua_dardo` or `lua_dardo_plus` to Luax — package and import
  changes plus notes on new APIs.

</div>

## Project layout

The Luax repo is organized around a few key entry points:

| Entry point | Purpose |
|---|---|
| `package:luax/lua.dart` | The main runtime API — `LuaState`, stack operations, async calls, events |
| `package:luax/lua_parser.dart` | Parser & AST surface for static analysis tooling |
| `package:luax/debug.dart` | Debug utilities (e.g. `LuaState.printStack()`) |
| `package:flutter_luax/flutter_lua.dart` | Flutter widget bindings (separate package) |

The API reference under [`/api/`](/api/) is generated from the `///` dartdoc
comments on these entry points. The guide pages under `/guide/` are hand-written
and live in this `docs/` directory.

## Contributing

See [`CONTRIBUTING.md`](https://github.com/NaivG/Luax/blob/main/CONTRIBUTING.md)
on GitHub for the development workflow, branch conventions, and review
process.
