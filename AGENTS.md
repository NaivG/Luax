# Repository Guidelines

## Project Overview

**lua_dardo_plus** (LuaDardo Plus) is a Lua 5.3 virtual machine implemented in pure Dart. It is a maintained fork that adds async function support, goto/label syntax, an exposed parser/AST for static analysis, and web platform compatibility.

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

## Test Structure

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

## Build and Test Commands

| Command | Purpose |
|---|---|
| `dart pub get` | Install dependencies |
| `dart run example/example.dart` | Run example |
| `dart test` | Full test suite |
| `dart test test/stdlib` | Standard library tests only |
| `dart test test/codegen` | goto/label codegen tests only |
| `dart test test/async` | Async function tests only |
| `dart test test/bugfix` | Bug fix regression tests only |
| `dart test test/perf` | Performance benchmarks |
| `dart analyze` | Static analysis (must pass with zero issues) |

## Key Conventions

### SDK and Language

- **Dart SDK**: `>=3.0.0 <4.0.0` — null safety is enabled by default.
- All code must be null-safe. No legacy opt-out.

### Formatting

- Run `dart format .` before committing.
- Use 2-space indentation (Dart default).

### Naming

| Element | Convention |
|---|---|
| Types (classes, enums, mixins, typedefs) | `UpperCamelCase` |
| Variables, functions, parameters | `lowerCamelCase` |
| Filenames | `snake_case.dart` |

### API Design

- The public API surface in `lib/` is kept small and documented.
- All implementation code lives under `lib/src/` and is not part of the public contract.
- When adding features, prefer extending existing classes or adding to `lib/src/` and re-exporting through `lib/lua.dart` if public.

### Testing

- Tests use `package:test` for assertions and structure.
- Property-based tests use `package:glados` (see `test/stdlib/` for examples).
- goto/label codegen has dedicated stress tests in `test/codegen/` (`goto_torture`).
- Regression tests for bug fixes go in `test/bugfix/` and reference the issue number.

### Commit Messages

Format: `<type>: <description>`

Supported types: `fix`, `feat`, `docs`, `test`, `refactor`, `perf`, `chore`.

Example: `fix: correct upvalue capture in nested closures`

## Dependencies

| Package | Source | Notes |
|---|---|---|
| `sprintf` | Git (Telosnex fork) | String formatting |
| `glados` | pub.dev | Property-based testing (dev) |
| `lints` | ^4.0.0 | Lint rules (dev) |
| `test` | ^1.25.0 | Test framework (dev) |

## Common Tasks

### Adding a new standard library function

1. Implement in the appropriate file under `lib/src/stdlib/`.
2. Register it in the library's open function.
3. Add tests under `test/stdlib/`.
4. Run `dart test test/stdlib` and `dart analyze`.

### Fixing a bug

1. Add a regression test in `test/bugfix/` that reproduces the issue.
2. Fix the bug in the relevant `lib/src/` module.
3. Run `dart test` to confirm no regressions.
4. Run `dart analyze`.

### Adding goto/label or parser features

1. Work in `lib/src/compiler/parser/` and `lib/src/compiler/codegen/`.
2. Update AST nodes in `lib/src/compiler/ast/` if needed.
3. Add tests in `test/codegen/` — include edge cases and stress tests.
4. Verify with `dart test test/codegen`.

### Adding async function support

1. Extend the relevant API in `lib/src/api/`.
2. Add tests in `test/async/`.
3. Ensure `dart test` passes.

## Reminders

- Always run `dart analyze` before committing — zero warnings expected.
- Always run `dart format .` before committing.
- Do not modify `pubspec.yaml` dependencies without discussion.
- When in doubt, check existing patterns in `lib/src/` and mirror them.
