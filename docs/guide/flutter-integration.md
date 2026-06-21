---
title: "Flutter Integration"
description: "Flutter widget bindings via the flutter_luax companion package"
outline: [2, 3]
library: "guide"
---

# Flutter Integration

For Flutter apps, Luax provides a companion widget bindings package,
[`flutter_luax`](https://github.com/NaivG/flutter_luax). It lets Lua scripts
construct Flutter widgets like `Scaffold`, `AppBar`, `Container`,
`ElevatedButton`, `ListView`, and more.

It also includes a `LuaxScriptLoader` for fetching `.lua` files from a URL or
Flutter asset bundle — useful when you want to push UI updates without
rebuilding the app.

## Adding the dependency

```yaml
dependencies:
  luax:
    git: https://github.com/NaivG/Luax.git
  flutter_luax:
    git: https://github.com/NaivG/flutter_luax.git
```

Then fetch:

```bash
flutter pub get
```

## Quick start

The widget bindings are exposed under the `flutter_lua` import. A minimal
example — a `Scaffold` with an `AppBar` and a centered `Text` — looks like
this in Lua:

```lua
return ui.Scaffold {
  appBar = ui.AppBar {
    title = ui.Text { text = "Hello from Lua" },
  },
  body = ui.Container {
    color = "#1e1e1e",
    child = ui.Center {
      child = ui.Text { text = "It works!" },
  },
}
```

This file can be loaded and rendered with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_luax/flutter_lua.dart';
import 'package:luax/lua.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final state = LuaState.newState();
  state.openLibs();
  await FlutterLuaBinding(state).register();

  final source = await rootBundle.loadString('assets/screen.lua');
  state.doString(source);

  runApp(MaterialApp(home: LuaWidget(state: state)));
}
```

The `LuaWidget` materializes whatever widget tree Lua returned.

## Hot-updating UI

`LuaxScriptLoader` is the right tool when you want to push UI updates
without an app rebuild. Two modes:

```dart
final loader = LuaxScriptLoader(
  state: state,
  source: LuaxScriptSource.url('https://example.com/screen.lua'),
);
```

or for an asset bundled with the app:

```dart
final loader = LuaxScriptLoader(
  state: state,
  source: LuaxScriptSource.asset('assets/screen.lua'),
);
```

`source` is an enum-like value (`url` / `asset` / `file` / `string`). The
loader fetches the source, runs it in the VM, and returns the resulting
widget.

## Architecture

![Integration Architecture](https://raw.githubusercontent.com/NaivG/Luax/main/assets/images/architecture.png)

The flow:

1. Lua script returns a widget tree description (a Lua table structure
   matching the Flutter widget hierarchy)
2. `flutter_luax` walks the description and instantiates the corresponding
   Flutter widgets
3. `LuaWidget` rebuilds when the VM state changes, hot-swapping the rendered
   tree

## Bidirectional communication

![Communication Flow](https://raw.githubusercontent.com/NaivG/Luax/main/assets/images/flow.png)

The Luax event system is the standard way to send messages from Dart to
Lua and back. See the [Event System guide](event-system.md) for the
API and security model.

A complete integration example with Riverpod state management is available
at [flutter_lua_example](https://github.com/ImL1s/flutter_lua_example).

## Widget reference

For the full list of supported widgets, layouts, and styling options, see
the [flutter_luax
README](https://github.com/NaivG/flutter_luax/blob/main/README.md).
