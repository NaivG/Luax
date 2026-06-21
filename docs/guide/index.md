---
title: "Guide"
description: "Task-oriented guides covering Dart↔Lua interop, async/await, event system, coroutines, GC, web, and Flutter"
outline: [2, 3]
editLink: false
prev: false
next: false
---

# Guide

Task-oriented guides for using Luax. Pick a topic below to dive in.

## Interop & APIs

<div grid="cols-2" gap="16">

- ### [Dart ↔ Lua Interop](dart-lua-interop.md)

  The full protocol for calling Dart from Lua, Lua from Dart, and reading Lua
  tables and functions across the boundary.

- ### [Async / Await](async-await.md)

  Call async Dart functions from Lua using the `await` keyword, or suspend
  inside `coroutine.resumeAsync`.

- ### [Event System](event-system.md)

  Bidirectional EventEmitter bridging Dart and Lua callbacks — including
  one-shot listeners, async listeners, and security sandboxing.

</div>

## Language features

<div grid="cols-2" gap="16">

- ### [Coroutines](coroutines.md)

  Full Lua 5.3 `coroutine` library — `create`, `yield`, `resume`, `wrap`,
  plus async-aware `resumeAsync`.

- ### [Language Features](language-features/)

  Luax's Lua 5.3+ extensions: `goto` / `::label::`, pattern matching with
  `%b` and `%f`, binary data packing, and function serialization.

</div>

## Runtime

<div grid="cols-2" gap="16">

- ### [Garbage Collection](garbage-collection.md)

  Incremental tri-color mark-and-sweep collector, `__gc` finalizers, weak
  tables, and the `collectgarbage()` API.

- ### [Parser & AST](parser-ast.md)

  Use `lua_parser` to build static analysis tools, linters, and code
  transformers on top of the Luax parser.

</div>

## Platforms

<div grid="cols-2" gap="16">

- ### [Web Platform](web-platform.md)

  Running Luax in the browser via the platform abstraction layer — supported
  APIs, limitations, and workarounds.

- ### [Flutter Integration](flutter-integration.md)

  The companion `flutter_luax` package: widget bindings, `LuaxScriptLoader`,
  and a complete integration example.

</div>

## Internals

- [Architecture](../architecture.md) — A deep-dive into the Luax VM:
  the compilation pipeline, the register-based execution model, state
  management, and the garbage collector.
