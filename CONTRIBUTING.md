# Contributing to LuaDardo Plus

## Fork Lineage

```
arcticfox1919/LuaDardo (original)
       │
       ▼
   ImL1s/LuaDardo (LuaDardo Plus)
       │
       ▼
   Telosnex/LuaDardo (Telosnex fork)
       │
       ▼
   NaivG/LuaDardo (this repo)
```

| Repository | Maintainer | Role |
|-----------|-----------|------|
| `arcticfox1919/LuaDardo` | arcticfox1919 | Original Lua 5.3 VM (inactive since July 2023) |
| `ImL1s/LuaDardo` | ImL1s | Bug fixes, web support, async functions, coroutines |
| `Telosnex/LuaDardo` | jpohhhh | goto/label, performance, parser restructure, 40+ bug fixes |
| `NaivG/LuaDardo` | NaivG | Current development (this repo) |

## Development Setup

```bash
# Clone the repository
git clone https://github.com/NaivG/LuaDardo.git
cd LuaDardo

# Install dependencies
dart pub get

# Run tests
dart test

# Run static analysis
dart analyze
```

## Workflow

### 1. Create a Feature/Fix Branch

```bash
git checkout develop
git checkout -b fix/issue-XX   # or feat/xxx
```

### 2. Implement Changes

- Write the fix or feature
- Add tests in the appropriate `test/` subdirectory
- Run tests: `dart test`
- Run analysis: `dart analyze`
- Format code: `dart format .`

### 3. Commit

```bash
git add .
git commit -m "fix: description of the fix"
```

Commit message format: `<type>: <description>`

Types: `fix`, `feat`, `docs`, `test`, `refactor`, `perf`, `chore`

### 4. Push and Open PR

```bash
git push -u origin fix/issue-XX
```

### 5. Publish New Version

```bash
# Update version in pubspec.yaml
# Update CHANGELOG.md
dart pub publish --dry-run  # Verify
dart pub publish
```

## Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking API changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

Current version: `0.3.1`

## Testing

All changes must include tests:

```bash
# Run all tests
dart test

# Run specific test directories
dart test test/stdlib        # Standard library tests
dart test test/codegen       # goto/label codegen tests
dart test test/async         # Async function tests
dart test test/perf          # Performance benchmarks
dart test test/bugfix        # Bug fix regression tests

# Run with coverage
dart test --coverage=coverage
```

Property-based tests use `package:glados` (see `test/stdlib/` for examples).

## Code Style

- Follow standard Dart formatting (`dart format .`)
- 2-space indentation
- `UpperCamelCase` for types, `lowerCamelCase` for variables/functions
- `snake_case.dart` for filenames
- Run `dart analyze` to check for issues (zero warnings expected)

## Project Structure

```
lib/
├── lua.dart              # Main entry point — public API
├── lua_parser.dart       # Parser & AST for static analysis
├── debug.dart            # Debug utilities (printStack)
└── src/
    ├── api/              # Core Lua API
    ├── binchunk/         # Binary chunk parsing
    ├── compiler/         # Lexer, Parser, AST, CodeGen
    ├── number/           # Numeric helpers
    ├── platform/         # Platform abstraction (IO/Web)
    ├── state/            # VM state (Stack, Table, Closure, etc.)
    ├── stdlib/           # Standard libraries
    ├── types/            # Exceptions, ThreadCache
    └── vm/               # VM instructions and opcodes

test/
├── async/                # Async function tests
├── bugfix/               # Regression tests
├── codegen/              # goto/label tests
├── coroutine/            # Coroutine tests
├── module/               # Module loading tests + Lua fixtures
├── perf/                 # Performance benchmarks
├── platform/             # Platform tests
├── state/                # Numeric handling tests
└── stdlib/               # Standard library tests
```

## Release Checklist

- [ ] All tests pass (`dart test`)
- [ ] Static analysis clean (`dart analyze`)
- [ ] Code formatted (`dart format .`)
- [ ] Version bumped in `pubspec.yaml`
- [ ] CHANGELOG.md updated
- [ ] README.md updated if needed
- [ ] `dart pub publish --dry-run` passes
- [ ] Tagged release: `git tag v0.x.x`
