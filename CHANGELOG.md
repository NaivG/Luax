# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `await` keyword for host async function calls (`await <func>(...)`). `await` is a hard-reserved Luax keyword (not part of standard Lua) and is recognized in both expression and statement positions, including chained `await obj.method()` and nested `await f(await g(x))`. The VM emits a new `ACALL` opcode that suspends execution until the registered async Dart closure completes and returns the actual result.
- `ACALL` opcode (`OpCodeKind.ACALL`, instruction number 47) — await-aware variant of `CALL`. The sync VM loop's `Instructions.aCall` raises a descriptive error if reached outside an async execution context, and the async VM loop routes the call through `_callTargetAsync(alwaysAwait: true)`.
- `AwaitExp` AST node with codegen support in `processAwaitExp` / `funcinfo.emitAsyncCall`. `StatParser` accepts `await func(args)` as a statement (wrapped in `FuncCallStat`); the statement codegen dispatches on the inner `AwaitExp` to emit `ACALL` instead of `CALL`.
- `coroutine.resumeAsync(co [, val1, ...])` — async counterpart of `coroutine.resume`. Required when a coroutine body calls host async functions without the `await` keyword: the surrounding `resumeAsync` call provides the suspension point, so direct calls to async-registered functions inside the coroutine body are awaited transparently. Mirrors `coroutine.resume` for yields, errors, and the `(bool, ...)` return tuple.
- Optional `name` parameter on `pushDartFunctionAsync(f, [name])` and `pushDartClosureAsync(f, n, [name])`; `registerAsync` passes the registered name through automatically. The name is stored on the new `Closure.name` field and surfaced in the "attempt to call async function `<name>` without await or in non-async context" runtime error message.
- `example/await_example.dart` — runnable example covering the three call modes (direct call returning the error tuple, explicit `await`, and coroutine body via `coroutine.resumeAsync`).

### Changed

- **Behavioural:** direct synchronous call to a host async Dart closure — either from Dart via `LuaState.call(...)` or from Lua via the `CALL` opcode — no longer throws. It now pushes a `(nil, "<message>")` tuple onto the stack where the message names the symbol that was called, allowing Lua scripts to branch on the error in the same way as pcall-style results. Statement calls (nResults == 0) silently drop the tuple; single-result calls keep only the leading `nil`. This is a breaking change for any caller that was catching the previous exception. Async paths (`pCallAsync`, `callAsync`, `doStringAsync`, `coroutine.resumeAsync`) are unaffected — they continue to await the closure directly.
- `callAsync` is now a thin wrapper over `_callTargetAsync(alwaysAwait: true)`, eliminating the duplicated dispatch logic that previously lived in `callAsync`. The shared path also picks up the coroutine-aware await semantics (`_insideResumeAsync` flag) for free.
- `resume` and `resumeAsync` share three private helpers — `_placeResumeArgs`, `_unwindAndPropagate`, `_popBodyFrame` — extracted from the original `resume` body. The async variant now sets an `_insideResumeAsync` flag for the duration of execution so `_callTargetAsync` knows to await host async closures encountered mid-frame.
- `Closure.DartFuncAsync` constructor signature now takes a leading `String? name` argument. The change is contained within the library: `pushDartFunctionAsync` / `pushDartClosureAsync` are the only callers and both were updated. Direct external construction will need to be updated.

### Fixed

- `coroutine.resume` and `coroutine.resumeAsync` now recognize `ACALL` as a valid resume point when placing resume arguments into the interrupted call's result slots (`_placeResumeArgs`). Previously the guard only matched `CALL` and `TAILCALL`, so a `coroutine.yield` inside a Lua function reached via `await` would drop the resume arguments on the floor. The change covers the new `ACALL` opcode alongside the two original cases.

### Tests

- New `await keyword` test group (`test/async/async_function_test.dart`) covering basic await, multiple return values, nested awaits, `await` on a sync host function (no-op), `await` as a statement, and `await` on a method call (table field).
- New `Direct async call returns error tuple` test group covering the new `(nil, error)` semantics for `doStringAsync` calls, single-result truncation, and statement-call discarding.
- New `coroutine resume after await-call` regression group (two tests) covering `_placeResumeArgs` correctness when the interrupted call is an `ACALL` — both the implicit (coroutine body) and explicit (`await` keyword) await paths.
- Three new `coroutine.resumeAsync` tests in `test/coroutine/coroutine_test.dart`: host async function called from a coroutine body, yielded values propagated to the caller, and error propagation as `(false, msg)`.
- Existing async integration tests updated to use the `await` keyword now that it is the supported way to invoke host async functions from Lua.

## [0.3.1] - 2026-06-13

### Added

- Incremental mark-and-sweep garbage collector (`LuaGarbageCollector`) compatible with Lua 5.3 semantics — tri-color marking, debt-based pacing, `__gc` finalizer support for tables and userdata, and full `collectgarbage()` API (`"collect"`, `"stop"`, `"restart"`, `"count"`, `"step"`, `"setpause"`, `"setstepmul"`, `"isrunning"`, `"info"`).
- Weak table support: tables with a `__mode` metatable field are registered with the collector on `setmetatable` and unregistered on metatable removal, with sweep-time cleanup of weakly-referenced keys/values that have become unreachable.
- `utf8` standard library — `utf8.char`, `utf8.codepoint`, `utf8.codes`, `utf8.len`, `utf8.offset`, and the `utf8.charpattern` pattern, working at the Unicode code-point level.
- Async call path for Lua closures and async Dart functions, enabling non-blocking interop between the two runtimes.
- Exposed the parser and AST via `lua_parser.dart`, allowing external tooling to parse and inspect Lua source.
- `goto`/`label` statements with forward and backward jumps following Lua 5.2+ scoping rules.
- Reference Lua 5.3 pattern matcher ported from C, adding support for `%b` (balanced match) and `%f` (frontier pattern).
- Runtime error messages now include the offending source line for easier debugging.
- `string.dump` — serialize Lua functions to binary chunk format.
- `string.pack`, `string.unpack`, and `string.packsize` for binary data packing/unpacking.

### Changed

- `LuaTable`, `Closure`, `Userdata`, and `LuaStateImpl` now mix in `GCObject` for tri-color mark-and-sweep tracking; the VM loop checks GC debt at regular intervals.
- Renamed package from `lua_dardo_plus` to `luax`.
- Parser is approximately 47% faster end-to-end via lexer and statement-parser tuning.
- `StatParser` is approximately 12% faster through the use of records and pre-sized lists.
- `sprintf` fork delivers roughly 5x speedup; simple format specifiers bypass `sprintf` entirely for an additional 3.7x gain.
- Fixed-capacity VM stack yields approximately 22% faster execution.
- Opcode dispatch no longer relies on stringly-typed comparison, reducing overhead per instruction.
- Updated minimum Dart SDK to 3+ for null-safety by default.
- **GC perf:** tri-color stored as integers (instead of strings) to reduce per-object overhead; gray-queue propagation extracted into `_propagateGray()` to remove duplication between the cycle and finalization paths; `restart()` resumes collection without forcing a full cycle; `__gc` and `__mode` metamethod lookups are cached to avoid repeated hash lookups during finalization and weak-table registration.
- **GC API:** `collectgarbage("info")` now reports a structured table reflecting the current collector state (running/paused, phase, debt, totals).

### Fixed

#### String library

- `string.reverse` no longer crashes on multi-character strings.
- `string.find` now returns capture groups and reports the correct end position when pattern length differs from match length.
- `string.match` returns the full match instead of only capture groups.
- `string.format` no longer crashes on `%q` (Lua quoted-string escaping implemented from scratch), nor on `%e`, `%E`, `%g`, `%G` specifiers.
- `string.gsub` now accepts function and table replacements (previously string-only), correctly interprets capture back-references (`%0`, `%1`, etc.), and skips empty-string input.
- `string.gmatch` re-anchors `^` on substrings, no longer uses `indexOf` to advance (which caused wrong matches and potential infinite loops), and handles matches at end-of-string without a `RangeError`.

#### Pattern / regex engine

- `luaPatternToRegex` now correctly handles dot/newline semantics, anchors, regex metacharacters, and lazy quantifier tracking.
- Lua character classes (`%a`, `%d`, `%w`, etc.) inside bracket sets no longer produce invalid nested regex.
- All Lua pattern classes (`%a`, `%d`, `%s`, `%l`, `%u`, `%w`, `%p`, `%c`, `%x`) are now translated to Dart regex equivalents.
- Literal dash immediately after a group parenthesis in `luaPatternToRegex` is escaped correctly.

#### Math library

- `math.fmod` uses truncation mod instead of floor mod, producing correct results for negative operands.
- `math.abs` now pushes a result for non-negative integer inputs (previously a missing return).
- `math.ult` performs unsigned comparison instead of signed, matching the Lua 5.3 specification.

#### OS library

- `os.date` now treats the time argument as an epoch timestamp (not a duration from now), actually formats the output string instead of returning the format string as-is, and together with `os.time` matches the Lua 5.3 specification.
- `os.clock` returns approximate CPU time instead of epoch wall-clock seconds.

#### Coroutine library

- Multi-resume no longer corrupts the stack — resume arguments are now placed as `CALL` results correctly.
- Resume properly unwinds nested call frames on yield/error.

#### Type coercion

- `toIntegerX` now coerces strings and floats, fixing `checkInteger` for string arguments.
- `toNumberX` now coerces strings to numbers, fixing `checkNumber` and `isNumber` for string arguments.
- Replaced overly-strict `int`/`double` checks with `num` throughout the runtime for consistent numeric handling.

#### Error handling

- `error()`, `pcall`, and `xpcall` no longer stringify non-string error objects — tables and numbers passed to message handlers are preserved intact.
- `xpcall` now invokes the message handler instead of throwing a `todo!` stub.
- `_checkTab` metamethod logic was inverted — checks are now performed when requested rather than skipped.

#### Numeric / bitwise internals

- Hex float parsing no longer overflows on exponents greater than 63.
- `logicalRShift` uses a full 64-bit mask instead of a 60-bit mask that zeroed bits 60-63 on every shift.
- `luaMaxInteger` is now correctly 2^63 - 1 (operator precedence bug `1 << 63 - 1` fixed).
- `tonumber` with base 16 now accepts `0x`/`0X` prefixed strings.
- Lexer `readNumeral` no longer misuses `startsWith` with multi-character strings; hex float parsing added.

#### VM / runtime

- `loadfile` reads the mode argument from stack index 2 (was reading from index 1); `dofile` no longer defaults the filename to `"bt"`.
- The `#` (length) operator on strings now returns a value (missing return added).
- `\xXX` and `\ddd` byte escapes are decoded as UTF-8 code points in Dart strings.
- Chunk IDs are truncated in error messages (ported `luaO_chunkid`) and in `traceStack()` frame labels.

#### Goto / labels

- Upvalue closing on `goto` jump now works correctly.
- Same-name label shadowing is handled per Lua 5.2+ scoping rules.

#### Debug

- `debug.dart` `printStack` had a duplicate `luaNil` case instead of `luaBoolean` — corrected.

#### Platform

- Platform command execution now runs through a shell so PATH and other environment variables resolve correctly across platforms.

### Build

- Added a GitHub Actions `dart analyze` workflow that runs on push and pull request, restricted to Dart source changes only.

### Tests

- GC unit tests and incremental state-machine tests (tri-color marking, cycle counting, `__gc` finalizers, debt-based pacing, `collectgarbage` API).
- Weak-table GC tests covering `__mode = "k"`, `"v"`, and `"kv"` for both automatic and manual collection paths.
- `utf8` library tests covering `char`, `codepoint`, `codes`, `len`, `offset`, and `charpattern` (including surrogate-pair handling and out-of-range inputs).
- GC performance benchmark (`gc_perf_test.dart`) for measuring cycle throughput.
- 56 gremlin torture tests for `goto`/`label` (forward jumps, backward jumps, upvalue closing, shadowing).
- Glados property-based tests for math, table, operators, and coroutines.
- Edge-case tests for `string.find`.
- Skip-failing test marker for the multi-resume coroutine bug.

## [0.3.0] - 2024-12-29

### Added
- **Web Platform Support** (#28): Full web compatibility via platform abstraction layer
  - Conditional imports for `dart:io` (native) and web stub
  - `PlatformServices` singleton for cross-platform file/process operations
  - Customizable `printCallback` for output redirection
  - Web-safe `os` library (time functions work, file operations throw `UnsupportedError`)
- **Async Dart Function Support** (#9): Call async Dart functions from Lua
  - `DartFunctionAsync` type: `Future<int> Function(LuaState ls)`
  - `registerAsync(name, func)` - Register async function as global
  - `pushDartFunctionAsync(func)` - Push async function onto stack
  - `pushDartClosureAsync(func, nUpvals)` - Push async closure with upvalues
  - `callAsync(nArgs, nResults)` - Call function asynchronously
  - `pCallAsync(nArgs, nResults, errFunc)` - Protected async call
  - `doStringAsync(code)` - Execute Lua string asynchronously
  - `doFileAsync(path)` - Execute Lua file asynchronously
- `luaUpvalueIndex(i)` helper function for accessing upvalues in closures
- 93 new tests (136 total, up from 43)

### Fixed
- **`math.min` bug**: Was returning maximum value instead of minimum (comparison logic inverted)
- **`math.modf` bug**: Was returning only fractional part (return count was 1 instead of 2)

### Changed
- Replaced deprecated `pedantic` with `lints: ^4.0.0` in dev_dependencies
- Updated `test` to `^1.25.0`

## [0.2.0] - 2024-12-29

### Added
- **Coroutine Support**: Full implementation of Lua coroutine library
  - `coroutine.create(f)` - Create a new coroutine
  - `coroutine.resume(co, ...)` - Start or resume a coroutine
  - `coroutine.yield(...)` - Suspend coroutine execution
  - `coroutine.status(co)` - Get coroutine status (running/suspended/dead)
  - `coroutine.running()` - Get the currently running coroutine
  - `coroutine.wrap(f)` - Create a wrapped coroutine function
- New API interfaces: `LuaCoroutineLib`, `LuaDebug`
- Thread type support in `LuaValue.typeOf()` and `LuaValue.typeName()`
- `ThreadStatus.luaDead` for completed coroutines
- 10 new coroutine tests

### Fixed
- **Issue #13**: `string.gsub` now works correctly
  - Fixed infinite loop when using unlimited replacement (n=-1)
  - Fixed off-by-one error in string slicing
  - Fixed original string modification during iteration

## [0.1.0] - 2024-12-29

### Added
- Forked from [arcticfox1919/LuaDardo](https://github.com/arcticfox1919/LuaDardo) v0.0.5
- Comprehensive test suite for bug fixes (21 tests)
- Per-instance metatable support for `Userdata` class
- Source location information in error messages (`[source:line]` format)
- `CONTRIBUTING.md` with branch strategy and workflow documentation

### Fixed
- **Issue #24**: `math.random` now correctly includes upper bound and supports negative ranges
  - `math.random(1, 10)` can now return 10
  - `math.random(-10, 10)` works correctly
- **Issue #33**: Error messages now include source file and line number information
- **Issue #34**: `return` without value no longer causes runtime error
  - `return` and `return;` correctly return nil
- **Issue #36**: Userdata metatables are now per-instance instead of shared globally

### Changed
- Renamed package from `lua_dardo` to `lua_dardo_plus`
- Updated SDK constraint to `>=2.17.0 <4.0.0`
- Improved README with migration guide and feature documentation

---

## Previous Releases (Original LuaDardo)

## 0.0.5
* Fix issues [#10](https://github.com/arcticfox1919/LuaDardo/issues/10)
* Fix warning

## 0.0.4
* Upgrade null safety

## 0.0.3
* Fix the bug of the table constructor
* Add auxiliary API for reference(`ref`/`unRef`)

## 0.0.2
* Add Lua userdata support
* Fix lexical analysis BUG

## 0.0.1
* A full lua virtual machine
* Support some standard libraries, e.g. String, Math, etc.
* Experimental nature only, not yet fully tested
