## Luax Architecture Deep-Dive

This document walks through the internal architecture of Luax. It covers the compilation pipeline, VM execution model, state management, garbage collection, and the key design decisions that shape the system.

---

### Overview

Luax is a register-based virtual machine that executes Lua 5.3 bytecode. The system has three major subsystems:

1. **Compiler** — Transforms Lua source code into bytecode through lexing, parsing, and code generation.
2. **Virtual Machine** — A register-based execution engine with both synchronous and asynchronous dispatch loops.
3. **Runtime** — Manages state, tables, closures, upvalues, coroutines, and garbage collection.

```
 Source String
      │
      ▼
   ┌────────┐
   │ Lexer  │  Tokenizes source into a stream of tokens
   └───┬────┘
       ▼
   ┌────────┐
   │ Parser │  Builds an AST (Block → Stmts + Exps)
   └───┬────┘
       ▼
   ┌─────────┐
   │ CodeGen │  Emits register-based bytecode instructions
   └───┬─────┘
       ▼
   ┌───────────┐
   │ Prototype │  Bytecode + constants + upvalue descriptors + sub-prototypes
   └───┬───────┘
       ▼
   ┌──────────┐
   │ Closure  │  Prototype + upvalue holders
   └───┬──────┘
       ▼
   ┌──────────────┐
   │ VM Execution │  Switch-based dispatch loop (sync or async)
   └──────────────┘
```

---

### Compilation Pipeline

The compiler lives under `lib/src/compiler/` and is orchestrated by the `Compiler` class.

#### Lexer (`lib/src/compiler/lexer/`)

The lexer converts a source string into a stream of `Token` objects (line number, token kind, value). It has two scanning paths, toggled by `Lexer.useFast`:

The **slow path** dispatches on single-character strings (`chunk.current`), building identifiers character-by-character with a `StringBuffer`. This is simpler to read but allocates per-character strings.

The **fast path** dispatches on integer code units (`chunk.currentCode`), which lets the `switch` statement compile to a jump table. Identifiers are captured in one `substring` call via a `sliceFrom` helper, and keyword lookup uses a single hash-map pass instead of character-by-character comparison. The fast path is the default and provides measurably better throughput.

The lexer caches one token of lookahead in `cachedNextToken`, consumed via `_shiftCache()`. The `await` keyword is recognized as a dedicated token (`TOKEN_KW_AWAIT`), making it a hard reserved keyword in Luax.

`CharSequence` wraps the source string and provides both a String-based API (`current`, `charAt`) and a zero-allocation code-unit API (`currentCode`, `codeAt`) for the fast lexer path.

String literal parsing handles `\xHH`, `\u{XXXX}`, and `\ddd` escape sequences. Multi-byte UTF-8 sequences are decoded correctly by accumulating pending bytes and flushing via `utf8.decode`.

#### Parser (`lib/src/compiler/parser/`)

The parser is a standard recursive-descent parser that produces an AST of `Node` subclasses.

`BlockParser` parses a sequence of statements followed by an optional return statement. It distinguishes between three return cases: `null` (no return statement), an empty list (`return` with no values), and a non-empty list (`return expr1, expr2`).

`StatParser` dispatches on the lookahead token to handle all Lua 5.3 statement forms, including `goto`/`label` and `await` expressions (a Luax extension).

`ExpParser` implements operator-precedence parsing for Lua expressions, producing a tree of `Exp` nodes. It handles the full set of Lua 5.3 operators with correct precedence and associativity.

`PrefixExpParser` handles the left-recursive prefix expression chain: variable names, parenthesized expressions, table access (`t[k]`), field access (`.field`), method calls (`:method(args)`), and function calls.

**Constant Folding (`Optimizer`):** The parser performs compile-time evaluation of constant expressions. This includes arithmetic on integer/float literals, logical short-circuit evaluation (`true or x` collapses to `true`), bitwise operations on constant integers, unary negation/not/bnot on literals, and right-associative power operator (`^`) folding.

#### Code Generation (`lib/src/compiler/codegen/`)

Code generation transforms the AST into register-based bytecode instructions.

`CodeGen.genProto()` wraps the top-level `Block` in a `FuncDefExp` (the main chunk is compiled as an anonymous vararg function with `_ENV` as its first local variable), creates a `FuncInfo`, processes it through `ExpProcessor`, and converts the result to a `Prototype` via `Fi2Proto`.

**FuncInfo** is the central data structure during code generation. It tracks:

- **Register allocation** — A bump allocator with a high-water mark (`maxRegs`). `allocReg(n)` reserves `n` consecutive registers; `freeReg(n)` releases them.
- **Local variables** — `LocVarInfo` entries with scope tracking, shadowing via `prev` chains, and capture detection (whether a local is captured as an upvalue by an inner function).
- **Upvalues** — Resolved recursively up the parent chain. If a name is a local in the immediate parent, it is captured as `instack=1`. If it is an upvalue in the parent, the chain is followed until a local is found.
- **Constants** — Deduplicated via a `Map<Object?, int>` to avoid duplicate entries in the constant pool.
- **Labels and gotos** — Forward-reference resolution with scope-aware label shadowing. Pending gotos are resolved when their target label is encountered.
- **Break handling** — A stack of breakable-scope breakpoint lists, so `break` jumps to the correct scope exit.

Instructions are emitted via typed helpers: `emitABC`, `emitABx`, `emitAsBx`, `emitAx` encode 32-bit instructions. Higher-level emitters exist for every opcode.

**BlockProcessor** processes statements sequentially, then handles the return statement. Tail calls are detected when the last return value is a single `FuncCallExp`, emitting `TAILCALL` + `RETURN` instead of a regular `CALL`.

**ExpProcessor** recursively processes expressions, classifying operands as register references, constants, upvalues, or combined RK encodings (where values > 0xFF index into the constant pool).

**Fi2Proto** converts the `FuncInfo` tree into a `Prototype` tree, serializing constants, upvalue descriptors, sub-prototypes, line info, and local variable debug information.

#### Binary Chunks (`lib/src/binchunk/`)

The `BinaryChunk` module supports both reading (`unDump`) and writing (`dump`) Lua 5.3 binary chunks. The format is byte-compatible with reference Lua 5.3: little-endian, 8-byte integers, 8-byte floats, 4-byte instructions.

An optional `strip` mode removes debug information (line info, local variable names, upvalue names) for smaller serialized output.

---

### VM Execution Model

Luax implements a **register-based** virtual machine following the Lua 5.3 instruction set. Each function has a fixed set of registers (R(0) through R(maxStackSize-1)) determined at compile time. Instructions reference registers by index through their A, B, and C operand fields.

#### Instruction Encoding

Each instruction is a 32-bit unsigned integer with four formats:

```
iABC:   [ B:9 ][ C:9 ][ A:8 ][ OP:6 ]
iABx:   [    Bx:18    ][ A:8 ][ OP:6 ]
iAsBx:  [   sBx:18    ][ A:8 ][ OP:6 ]
iAx:    [         Ax:26       ][ OP:6 ]
```

The opcode occupies the lowest 6 bits. The A field spans bits 6-13. For iABC, C is bits 14-22 and B is bits 23-31. For iABx/iAsBx, Bx occupies the upper 18 bits (with sBx biased by 131071).

#### Opcode Set

Luax implements 48 opcodes (indices 0-47), comprising the complete Lua 5.3 set plus one custom opcode:

`ACALL` (opcode 47) — An await-aware function call. When the callee is an async Dart function, the VM suspends execution and `await`s the result before continuing. This is the core mechanism enabling transparent async interop.

Every `OpCode` entry carries metadata (test flag, set-A flag, argument modes, encoding mode, name) and an `action` function pointer for indirect dispatch.

#### Dispatch Loop

The main execution loop (`_runLuaClosure` in `LuaStateImpl`) uses a **switch-based dispatch** on the raw 6-bit opcode integer extracted from `inst & 0x3F`. This was explicitly chosen over indirect function dispatch (which looked up `OpCode.action` and called `Function.call()`) for approximately 10% performance improvement, as the Dart compiler can compile the switch into a jump table.

Each iteration of the loop:

1. **Fetch:** `code[pc++]` reads the next instruction — a single array access plus increment.
2. **Dispatch:** The `switch` routes to the corresponding `Instructions.*` static method.
3. **GC check:** Every 64 instructions, the garbage collector debt is checked and the GC state machine advances if needed.
4. **Termination:** The loop exits when `RETURN` (opcode 38) is executed.

Individual instructions follow a consistent pattern. For example, `ADD` does:
```
getRK(B); getRK(C); arith(ADD); replace(A);
```
This pushes two operands (resolved from register or constant pool using RK encoding), performs arithmetic via the `Arithmetic` class (which falls through to metamethods when necessary), and stores the result into register A.

#### Async Dispatch Loop

`_runLuaClosureAsync` is an identical loop marked `async`, with `await` inserted at four opcodes: `CALL` (36), `TAILCALL` (37), `ACALL` (47), and `TFORCALL` (41). These opcodes route through `_execCallAsync`, `_execTailCallAsync`, and `_execTForCallAsync`, which resolve the callee and `await` it if it is an async Dart closure. All other opcodes execute synchronously within the async loop.

The `_insideResumeAsync` flag (set in `resumeAsync` and `callCoroutineAsync` via try/finally) enables transparent awaiting inside coroutine bodies. When this flag is true, host async functions called via a plain `CALL` instruction (without explicit `await`) are automatically awaited instead of producing an error tuple.

#### FPB Encoding

`NEWTABLE` uses "Floating Point Byte" (FPB) encoding to compress array/hash size hints into 8 bits (5-bit exponent + 3-bit mantissa). This matches the encoding used by reference Lua 5.3.

---

### State Management

#### `LuaStateImpl`

The central class, mixing in `GCObject` for garbage collection. It implements both `LuaState` (the public API) and `LuaVM` (the internal VM interface). Key fields:

- `_stack` — The current `LuaStack` frame (a linked list, with the most recent call on top).
- `registry` — A `LuaTable` serving as the global registry. Index 2 (`luaRidxGlobals`) holds the global environment table `_G`.
- `status` — Coroutine status (`luaOk`, `luaYield`, `luaDead`, etc.).
- `_gc` — The garbage collector instance.
- `_insideResumeAsync` — Flag for transparent async awaiting inside coroutine bodies.

#### `LuaStack` — Call Frames

Each `LuaStack` instance represents a single call frame. It has two modes, toggled by `LuaStateImpl.useFixedStack`:

**Fixed-capacity mode** (default): A pre-allocated `List<Object?>` with an explicit `_top` pointer. Push is `slots[_top++] = val`; pop is `val = slots[--_top]; slots[_top] = null` (nulling for GC friendliness). This avoids list resizing and `removeAt` overhead. The array grows by doubling when capacity is exceeded.

**Growable mode** (legacy baseline): A plain `List<Object?>` using `add`/`removeAt`. Simpler but slower due to per-element allocation and shifting.

Each stack frame carries:

- `closure` — The `Closure` being executed.
- `pc` — Program counter (instruction index).
- `varargs` — The vararg arguments for the current call.
- `openuvs` — Map of open (not yet closed) upvalues, keyed by stack slot index.
- `gcTop` — Upper bound for GC root tracing. Set to `maxStackSize` for Lua closure frames so the GC sees all compiler-allocated registers even when the operational top is temporarily lower. This prevents premature collection of values stored in higher registers.
- `prev` — Link to the caller's stack frame.

The stack supports both register indexing (1-based) and pseudo-indices: `luaRegistryIndex` (-1,001,000) accesses the registry table, and indices below that access upvalues of the current closure.

#### `LuaTable`

A hybrid array+hash-map implementation matching Lua's table semantics:

- `arr` — A `List<Object?>` for the array part (1-indexed keys stored at 0-indexed positions).
- `map` — A `HashMap<Object?, Object>` for the hash part.
- `keys` — A lazily-built linked-list map for `next()` iteration order.
- `metatable` — Optional per-table metatable.
- `weakMode` — Captured at `setmetatable` time (`null`, `'k'`, `'v'`, or `'kv'`).

Key behaviors:

- **Integer key promotion:** `put()` auto-converts float keys that are integer-valued (e.g., `1.0` becomes `1`).
- **Array expansion:** When setting index `arrLen + 1`, the hash map is swept for consecutive keys that can migrate into the array.
- **Array shrinking:** When the last array element is set to nil, trailing nils are removed.
- **Weak mode:** GC integration respects weak mode, skipping weak keys and/or values during the mark phase.

#### `Closure`

Three construction modes:

1. `Closure(Prototype)` — A Lua function with a prototype and upvalue slots.
2. `Closure.DartFunc(DartFunction, nUpvals)` — A synchronous Dart callback.
3. `Closure.DartFuncAsync(name, DartFunctionAsync, nUpvals)` — An async Dart callback with an optional name for error messages.

All closures are GC-tracked. The `traceReferences` method walks upvalue values and recursively traces constants in all sub-prototypes.

#### `UpvalueHolder`

Implements Lua's open/closed upvalue semantics:

- **Open:** `stack` is non-null, `index` points to a stack slot. `get()`/`set()` read/write through to the stack.
- **Closed:** `stack` is null, `value` holds the captured value directly.

`migrate()` copies the value from the stack into `value` and sets `stack = null`, converting an open upvalue into a closed one. Upvalues are closed by `closeUpvalues(a)`, which is called by `JMP` and `RETURN` instructions and iterates the `openuvs` map, migrating all upvalues at or above slot `a`.

---

### Garbage Collection

Luax implements a custom **incremental mark-and-sweep garbage collector** (`lib/src/gc/garbage_collector.dart`) that cooperates with Dart's GC rather than replacing it.

#### Object Tracking

All `GCObject` instances (`LuaTable`, `Closure`, `Userdata`, `LuaStateImpl`/threads) self-register with `LuaGarbageCollector.current` in their constructors. Each object carries a 2-bit color field for tri-color marking (white, gray, black).

#### State Machine

The GC runs as an incremental state machine: `pause → markPropagate → sweep → finalize → pause`. It is driven by allocation debt — every 64 VM instructions, `checkDebt()` is called, advancing the state machine proportionally to accumulated debt.

**Roots:** The registry table and all non-dead threads.

**Weak tables:** Tables with `__mode` set are registered when `setmetatable` is called. Before sweep, entries whose weakly-referenced keys/values are unreachable (still white) are removed.

**`__gc` finalizers:** Dead objects with `__gc` metamethods are "resurrected" (re-marked as reachable), then finalized in LIFO order. Objects can be re-resurrected by their finalizer.

**Tuning:** Default pause of 200% (start a new cycle when estimated memory doubles) and step multiplier of 200% (GC works at 2x the allocation rate).

#### GC Scope Guards

`_withGcScope` and `_withGcScopeAsync` save and restore the static `LuaGarbageCollector.current` pointer around Dart callback invocations. This ensures objects allocated inside host functions are tracked by the correct collector even in multi-thread scenarios.

---

### Platform Abstraction

The platform layer (`lib/src/platform/`) uses Dart's conditional imports to select between native and web implementations at compile time:

```dart
import 'platform_io.dart'
    if (dart.library.js_interop) 'platform_web.dart' as platform_impl;
```

`PlatformServices` is an abstract singleton with methods for file I/O, environment variables, process execution, printing, and platform detection. It can be overridden with `PlatformServices.init()` for testing or custom environments.

`NativePlatformServices` delegates to `dart:io` for real file operations, process execution, and environment variable access.

`WebPlatformServices` provides stub implementations that return `null`/`false` for file operations and throw `UnsupportedError` for destructive operations. `print()` routes to the browser console. The path separator is hardcoded to `/`.

File-loading operations in `LuaStateImpl` check `PlatformServices.instance.supportsFileSystem` before attempting I/O, gracefully returning `luaErrFile` on web.

---

### Error Handling

Runtime errors follow a layered approach:

**`LuaError`** wraps the raw Lua error value (which can be any type — table, number, string) so it can be thrown as a Dart exception without type loss.

**`LuaYieldException`** is an internal exception used to implement `coroutine.yield()`. When `yield` is called, it throws this exception, which is caught by the coroutine resume machinery.

**Error formatting** enriches messages with source location and a snippet of the offending source line:
```
[string "..."]:103: attempt to index a nil value
  > local day_len_sec = s.day_length or 0
```
The `chunkid` method implements Lua 5.3's `luaO_chunkid` logic for truncating long source identifiers.

**Protected calls** (`pCall` / `pCallAsync`) wrap `call` in a try/catch. On error, the stack is unwound back to the caller's frame, and either the raw `LuaError.value` (preserving tables, numbers, etc.) or the string representation of the exception is pushed.

**Async error surfacing:** When a host async function is called without `await` in synchronous context, `_pushAsyncNotAwaitedError` pushes a `(nil, error_message)` tuple instead of crashing, letting Lua scripts handle the error gracefully.

**Arithmetic/Comparison errors:** The `Arithmetic` and `Comparison` classes fall through to metamethods (`__add`, `__eq`, etc.) before throwing. All error messages include the type name of the offending value.

---

### Coroutine Implementation

Coroutines are implemented as lightweight `LuaStateImpl` threads sharing the same global environment (registry) but maintaining independent stacks.

**Creation:** `newThread()` creates a new `LuaStateImpl` instance, allocates a stack frame for the coroutine body function, and pushes the thread onto the parent's stack.

**Resume:** `resume(nArgs)` pushes arguments onto the coroutine's stack, then enters the execution loop. If the coroutine yields (via `LuaYieldException`), the exception is caught, the stack frame is preserved, and control returns to the caller.

**Yield:** `coroutine.yield(...)` throws a `LuaYieldException` carrying the number of return values on the stack. The resume machinery catches this, saves the coroutine state, and returns to the caller.

**Async coroutines:** `resumeAsync(nArgs)` and `callCoroutineAsync(nArgs)` use the async dispatch loop and set the `_insideResumeAsync` flag. This flag tells the VM to transparently await any host async functions encountered via plain `CALL` instructions, without requiring explicit `await` on every call inside the coroutine body.

---

### Design Decisions and Patterns

**Dual dispatch strategies:** Both the lexer (string-based vs. code-unit-based) and the VM (function-pointer vs. switch-based) have A/B toggle flags for benchmarking. The optimized paths are the defaults, but the alternatives are preserved for regression testing.

**Dual stack representations:** `LuaStack` supports both fixed-capacity (optimized) and growable (legacy) modes. The fixed-capacity mode avoids list resizing and enables efficient bulk operations.

**Async as a first-class extension:** Rather than bolting async onto the side, Luax extends the instruction set with `ACALL` and provides parallel sync/async execution paths. The `_insideResumeAsync` flag enables transparent awaiting inside coroutine bodies.

**Constant folding at parse time:** The `Optimizer` performs arithmetic, logical, and bitwise constant folding during parsing, reducing bytecode size and eliminating runtime work.

**Parser/AST as a separate library:** `lib/lua_parser.dart` exports only the AST and parser types, allowing static analysis tools to consume the parser without pulling in the entire VM runtime.

**Per-instance userdata metatables:** Unlike a shared-per-type approach, each `Userdata` instance has its own metatable, matching Lua's table semantics.

**Register-count-based GC root tracing:** `gcTop` on each stack frame is set to `maxStackSize` for Lua closure frames, ensuring the GC sees all compiler-allocated registers even when the operational top is temporarily lower.
