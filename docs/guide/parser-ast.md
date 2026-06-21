---
title: "Parser & AST"
description: "Exposed Lua parser and AST surface for building static analysis tools"
outline: [2, 3]
library: "guide"
---

# Parser & AST

The parser and AST are exposed as a separate library for building static
analysis tools, linters, code formatters, and source-to-source transformers.

## Parsing Lua source

```dart
import 'package:luax/lua_parser.dart';

void main() {
  final parser = Parser('print("hello")', 'example.lua');
  final block = parser.parse();
  // Inspect the AST: block.stats, expressions, etc.
}
```

`Parser.parse()` returns a [`Block`](/api/lua_parser/Block) — the root of
the AST. A `Block` has a list of statements (`stats`) and an optional list of
return expressions (`retExps`).

## AST node types

The AST has three top-level abstract classes:

- [`Node`](/api/lua_parser/Node) — the common base. Every node has `line` and
  `lastLine` numbers.
- [`Stat`](/api/lua_parser/Stat) — a statement. Concrete subclasses include
  `AssignStat`, `IfStat`, `WhileStat`, `ForNumStat`, `ForInStat`,
  `FuncCallStat`, `LocalVarDeclStat`, `GotoStat`, `LabelStat`, and more.
- [`Exp`](/api/lua_parser/Exp) — an expression. Concrete subclasses include
  `NilExp`, `TrueExp`, `FalseExp`, `IntegerExp`, `FloatExp`, `StringExp`,
  `NameExp`, `BinopExp`, `UnopExp`, `FuncCallExp`, `TableConstructorExp`,
  `FuncDefExp`, and the Luax-specific `AwaitExp`.

See [`/api/lua_parser/`](/api/lua_parser/) for the full class list.

## A small linter

Here's a working example that warns on `goto` statements (useful if you want
to enforce structured control flow in a codebase):

```dart
import 'package:luax/lua_parser.dart';

class GotoFinder {
  int count = 0;
  void walk(Node node) {
    if (node is GotoStat) {
      count++;
      print('  line ${node.line}: goto ${node.name}');
    }
    // AST traversal is left to the reader — every Stat and Exp has a
    // typed `toString()` for debugging, and the structure is uniform.
  }
}

void main() {
  final src = '''
    for i = 1, 10 do
      for j = 1, 10 do
        if i*j > 50 then goto done end
      end
    end
    ::done::
  ''';
  final block = Parser(src, 'example.lua').parse();
  final finder = GotoFinder();
  // ... walk the AST ...
  print('total gotos: ${finder.count}');
}
```

## Debug utilities

A debug utility is also available for inspecting the Lua stack at runtime:

```dart
import 'package:luax/debug.dart';

state.printStack();  // Prints stack contents with types and values
```

The `printStack` extension is in the `debug` library — see
[`LuaStateDebug`](/api/debug/LuaStateDebug) for the full surface.

## When to use the parser

The parser is the right tool when you want to do any of the following:

- **Lint code** without running it — find anti-patterns, deprecated APIs,
  style violations
- **Reformat code** — `dart_style`-style layout, indentation normalization
- **Generate code** — write Lua that writes more Lua
- **Extract documentation** — pull doc comments and signatures for an API
  reference
- **Build IDE tooling** — autocomplete, go-to-definition, find-references

For runtime introspection (the current call stack, local variable values,
function arguments), use the
[`LuaDebug`](/api/lua/LuaDebug) hooks API instead.

## A note on the `await` extension

The Luax parser accepts the `await` keyword (added in 0.3.1) as a unary
prefix on function call expressions. In the AST, `await foo(args)`
parses as an `AwaitExp` whose `exp` field is the inner `FuncCallExp`:

```dart
// AST shape: AwaitExp { exp: FuncCallExp { ... } }
```

If you're building a tool that walks the AST, handle `AwaitExp` explicitly
or it will be invisible to traversal. The simplest approach is to add a
case in your visitor:

```dart
if (node is AwaitExp) walk(node.exp);
```
