# Project Context

## Project Name

**lua_dardo_plus** (LuaDardo Plus)

## Overview

LuaDardo Plus is a Lua 5.3 virtual machine implemented entirely in pure Dart. It is a maintained fork chain of the original LuaDardo project, with added support for async functions, goto/label syntax, an exposed parser and AST for static analysis tooling, and web platform compatibility.

## Key Technologies

- **Language**: Dart (SDK `>=3.0.0 <4.0.0`, null safety enabled)
- **Emulated Language**: Lua 5.3
- **Key Dependencies**:
  - `sprintf` — Git dependency from Telosnex's fork, used for Lua-compatible string formatting
  - `test` (^1.25.0) — Test framework
  - `glados` — Property-based testing library
  - `lints` (^4.0.0) — Dart lint rules

## Project Structure

```
lib/
├── lua.dart              # Main entry point — exports public API
├── lua_parser.dart       # Parser & AST surface for static analysis tools
├── debug.dart            # Debug utilities (LuaStateDebug extension with printStack)
└── src/
    ├── api/              # Core Lua API definitions (LuaState, BasicAPI, AuxLib, Type, Coroutine, Debug, VM)
    ├── binchunk/         # Binary chunk parsing and serialization
    ├── compiler/         # Lexer, Parser, AST (exp/stat/block/node), CodeGen
    │   ├── ast/          # AST node types (Block, Exp, Stat, Node)
    │   ├── codegen/      # Code generation (BlockProcessor, ExpProcessor, StatProcessor, Fi2Proto, FuncInfo)
    │   ├── lexer/        # Lexer (CharSequence, Token)
    │   └── parser/       # Parser (BlockParser, ExpParser, PrefixExpParser, StatParser, Optimizer)
    ├── number/           # Numeric helpers (LuaMath, LuaNumber)
    ├── platform/         # Platform abstraction (platform.dart, platform_io.dart, platform_web.dart)
    ├── state/            # VM state (LuaStateImpl, LuaStack, LuaTable, Closure, UpvalueHolder, LuaValue, Userdata, Arithmetic, Comparison, LuaError)
    ├── stdlib/           # Standard libraries (Basic, Math, OS, String, Table, Coroutine, Package, LuaPattern, Constants)
    ├── types/            # Types (Exceptions, ThreadCache)
    └── vm/               # VM instructions and opcodes (Instruction, Instructions, Opcodes, FPB)
```

```
test/
├── async/        # Async function tests
├── bugfix/       # Bug fix regression tests (issues_test, issue13_gsub, chunkid)
├── codegen/      # goto/label tests (goto_label, goto_gremlin, goto_torture)
├── coroutine/    # Coroutine tests
├── module/       # Module loading tests + Lua fixtures (*.lua)
├── perf/         # Performance benchmarks (lexer, stat_parser, fixed_stack, string_format)
├── platform/     # Platform abstraction tests
├── state/        # Numeric handling tests
└── stdlib/       # Standard library tests (basic, math, string, table, os, pattern, glados property tests)
```

## Build and Run Commands

```sh
# Install dependencies
dart pub get

# Run the example
dart run example/example.dart

# Run the full test suite
dart test

# Run specific test directories
dart test test/stdlib       # Standard library tests
dart test test/codegen      # goto/label codegen tests
dart test test/async        # Async function tests
dart test test/perf         # Performance benchmarks
dart test test/bugfix       # Bug fix regression tests

# Static analysis (must pass cleanly)
dart analyze

# Format code before committing
dart format .
```

## Development Conventions

### Naming

- **Types** (classes, enums, mixins, typedefs): `UpperCamelCase`
- **Variables, functions, parameters**: `lowerCamelCase`
- **Filenames**: `snake_case.dart`

### Code Style

- 2-space indentation (Dart standard).
- All code is null-safe. No legacy opt-out.
- Run `dart format .` before every commit.
- Run `dart analyze` before every commit — zero warnings expected.

### API Boundaries

- The public API surface (`lib/lua.dart`, `lib/lua_parser.dart`, `lib/debug.dart`) is kept small and documented.
- Implementation lives under `lib/src/` and is not part of the public contract.
- New public symbols must be explicitly exported from the top-level library files.

### Commit Messages

Format: `<type>: <description>`

Types: `fix`, `feat`, `docs`, `test`, `refactor`, `perf`, `chore`

## Notable Features

### goto/label Support

The compiler fully supports Lua 5.3 `goto` and `::label::` syntax. The codegen for goto/label is tested extensively in `test/codegen/`, including:

- `goto_label` — basic goto/label functionality
- `goto_gremlin` — edge cases and tricky interactions
- `goto_torture` — stress tests with deeply nested and complex control flow

### Exposed Parser and AST

The parser and AST are exposed as a first-class surface via `lib/lua_parser.dart`, enabling external tools to perform static analysis on Lua source code. AST node types are organized under `lib/src/compiler/ast/` (Block, Exp, Stat, Node).

### Async Functions

LuaDardo Plus extends the Lua VM with async function support, allowing Dart `Future`-based operations to be called from Lua scripts. Tests are in `test/async/`.

### Web Platform Support

Platform-specific behavior is abstracted through `lib/src/platform/`, with separate implementations for IO (`platform_io.dart`) and web (`platform_web.dart`), enabling the VM to run in browser environments.

### Debug Utilities

`lib/debug.dart` provides a `LuaStateDebug` extension with a `printStack` method for inspecting the Lua stack during development and troubleshooting.

## Key Test Patterns

### Property-Based Testing with Glados

Standard library tests in `test/stdlib/` use `package:glados` for property-based testing. This generates random inputs to verify that stdlib functions behave correctly across a wide range of values. When adding new stdlib functions, follow this pattern and include glados-based property tests alongside specific unit tests.

### Regression Tests

Bug fixes get regression tests in `test/bugfix/` that reference the issue number (e.g., `issues_test`, `issue13_gsub`, `chunkid`). Always add a regression test when fixing a bug.

### Performance Benchmarks

Performance-sensitive code has benchmarks in `test/perf/` covering the lexer, statement parser, fixed stack operations, and string formatting. Run `dart test test/perf` to check for regressions.

## Common Tasks

### Using the public API

```dart
import 'package:lua_dardo_plus/lua.dart';
```

### Using the parser for static analysis

```dart
import 'package:lua_dardo_plus/lua_parser.dart';
```

### Using debug utilities

```dart
import 'package:lua_dardo_plus/debug.dart';
```

### Adding a new stdlib function

1. Implement in the appropriate file under `lib/src/stdlib/`.
2. Register it in the library's open function (e.g., `BasicLib.open`, `StringLib.open`).
3. Add unit tests and glados property tests in `test/stdlib/`.
4. Run `dart test test/stdlib` and `dart analyze`.

### Fixing a bug

1. Write a regression test in `test/bugfix/` that reproduces the issue first.
2. Fix the bug in the relevant `lib/src/` module.
3. Run `dart test` to confirm the fix and no regressions.
4. Run `dart analyze`.

### Working on the compiler

1. Lexer changes go in `lib/src/compiler/lexer/`.
2. Parser changes go in `lib/src/compiler/parser/`.
3. AST changes go in `lib/src/compiler/ast/`.
4. Code generation changes go in `lib/src/compiler/codegen/`.
5. Add or update tests in `test/codegen/` for goto/label changes.
6. Run `dart test` and `dart analyze`.
