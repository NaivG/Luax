---
title: "Event System"
description: "Bidirectional EventEmitter bridging Dart and Lua callbacks"
outline: [2, 3]
library: "guide"
---

# Event System

Luax includes a bidirectional EventEmitter that lets Dart and Lua code
subscribe to and fire shared events. The event bus is shared across the
`LuaState` and all its coroutines — any thread can `emit` and any thread can
listen.

## Dart side

```dart
final state = LuaState.newState();
state.openLibs();

// Subscribe from Dart
state.on('greet', (args) {
  print('Hello from Dart! ${args.first}');
});

// Fire from Dart — triggers both Dart and Lua listeners
state.emit('greet', ['world']);

// One-shot listener
state.once('login', (args) => print('User logged in'));

// Async listener
state.onAsync('fetch', (args) async {
  await Future.delayed(Duration(seconds: 1));
  print('Fetched ${args.first}');
});
await state.emitAsync('fetch', ['data']);

// Unsubscribe by id
final id = state.on('tick', (args) => print('tick'));
state.off('tick', listenerId: id);
```

## Lua side

```lua
-- Subscribe from Lua
local id = event.on("greet", function(name)
  print("Hello from Lua!", name)
end)

-- Fire from Lua — triggers both Dart and Lua listeners
event.emit("greet", "world")

-- One-shot listener
event.once("login", function()
  print("User logged in")
end)

-- Unsubscribe
event.off("greet", id)
```

## Dart Event API Reference

| Method | Description |
|--------|-------------|
| `on(event, callback)` | Register a Dart listener; returns a listener id |
| `onAsync(event, callback)` | Register an async Dart listener |
| `once(event, callback)` | Register a one-time listener; auto-removed after first fire |
| `off(event, {callback, listenerId})` | Remove a listener by callback reference or id |
| `emit(event, [args])` | Synchronously fire all listeners |
| `emitAsync(event, [args])` | Asynchronously fire all listeners |
| `removeAllListeners([event])` | Remove all listeners for one event or all events |

## Lua Event API Reference

| Function | Description |
|----------|-------------|
| `event.on(name, fn)` | Register a Lua listener; returns a listener id |
| `event.once(name, fn)` | Register a one-time Lua listener |
| `event.off(name, fn_or_id)` | Remove a listener by function reference or id |
| `event.emit(name, ...)` | Synchronously fire all listeners |
| `event.emitAsync(name, ...)` | Asynchronously fire all listeners |

## Security

Security sandboxing was taken into account from the very beginning of the event
system's design. The Lua side is not permitted to perform any operations that
could pose a risk to the host system.

When removing a listener through the `off` function, the Lua side can only
remove listeners registered by itself. `removeAllListeners` is ONLY available
to the Dart side. This is to prevent the Lua side from accidentally removing
listeners, which could cause the Dart side to crash.

The `emit` and `emitAsync` functions can call all registered listeners. All
things considered, that is acceptable.

## A bidirectional example

```dart
// Dart side
state.on('request:login', (args) async {
  final username = args[0] as String;
  final password = args[1] as String;
  // ... validate credentials ...
  state.emit('response:login', ['ok', username]);
});

state.onAsync('log', (args) async {
  print('[lua] ${args.join(' ')}');
});
```

```lua
-- Lua side
event.on("response:login", function(status, user)
  print("login result:", status, user)
end)

event.emit("log", "starting login flow")
event.emit("request:login", "alice", "s3cret")
```

See [`LuaEventAPI`](/api/lua/LuaEventAPI) for the full Dart API surface.
