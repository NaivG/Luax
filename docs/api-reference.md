## Luax API Reference

This document covers every public type, method, and constant exposed through the `lua.dart`, `lua_parser.dart`, and `debug.dart` libraries.

**Package:** `luax` v0.3.1 &nbsp;|&nbsp; **Dart SDK:** `>=3.0.0 <4.0.0`

---

### Getting Started

```dart
import 'package:luax/lua.dart';

void main() {
  final state = LuaState.newState();
  state.openLibs();
  state.doString('print("Hello from Luax!")');
}
```

For async host functions:

```dart
state.registerAsync('fetchData', (LuaState ls) async {
  final url = ls.checkString(1)!;
  final response = await http.get(Uri.parse(url));
  ls.pushString(response.body);
  return 1;
});

await state.doStringAsync('local data = await fetchData("https://example.com")');
```

---

### Core Types and Enumerations

#### `LuaType`

Identifies the runtime type of a Lua value.

| Value | Meaning |
|---|---|
| `luaNil` | The `nil` value |
| `luaBoolean` | Boolean (`true` / `false`) |
| `luaLightUserdata` | Light userdata (raw Dart object pointer) |
| `luaNumber` | Number (integer or float) |
| `luaString` | String |
| `luaTable` | Table |
| `luaFunction` | Lua closure or Dart callback |
| `luaUserdata` | Full userdata (`Userdata<T>`) |
| `luaThread` | Coroutine thread |
| `luaNone` | Invalid stack index |

#### `ArithOp`

Arithmetic operations for `arith()`.

`luaOpAdd`, `luaOpSub`, `luaOpMul`, `luaOpMod`, `luaOpPow`, `luaOpDiv`, `luaOpIdiv`, `luaOpBand`, `luaOpBor`, `luaOpBxor`, `luaOpShl`, `luaOpShr`, `luaOpUnm`, `luaOpBnot`

#### `CmpOp`

Comparison operations for `compare()`.

| Value | Meaning |
|---|---|
| `luaOpEq` | Equality (`==`) |
| `luaOpLt` | Less than (`<`) |
| `luaOpLe` | Less than or equal (`<=`) |

#### `ThreadStatus`

Status codes returned by load/call/resume operations.

| Value | Meaning |
|---|---|
| `luaOk` | No errors |
| `luaYield` | Thread is suspended |
| `luaDead` | Thread has finished or errored fatally |
| `luaErrRun` | Runtime error |
| `luaErrSyntax` | Syntax error during compilation |
| `luaErrMem` | Memory allocation error |
| `luaErrGcmm` | Error in a `__gc` metamethod |
| `luaErrErr` | Error while running the message handler |
| `luaErrFile` | File-related error (e.g., file not found) |

#### Function Typedefs

```dart
typedef DartFunction = int Function(LuaState ls);
typedef DartFunctionAsync = Future<int> Function(LuaState ls);
```

`DartFunction` is a synchronous Dart callback callable from Lua. The return value indicates how many results were pushed onto the Lua stack.

`DartFunctionAsync` is the async counterpart. The returned `Future` resolves to the number of results pushed.

---

### `LuaState`

The central class for all Lua operations. Obtain an instance via the factory constructor:

```dart
LuaState state = LuaState.newState();
```

`LuaState` extends `LuaBasicAPI` and implements `LuaAuxLib`, `LuaCoroutineLib`, and `LuaDebug`. The concrete implementation (`LuaStateImpl`) is internal.

#### Constants

| Constant | Value | Description |
|---|---|---|
| `luaMinStack` | 20 | Minimum stack size |
| `luaMaxStack` | 1,000,000 | Maximum stack size |
| `luaRegistryIndex` | -1,001,000 | Pseudo-index for the registry table |
| `luaMultret` | -1 | Signals "return all results" |
| `luaRidxGlobals` | 2 | Registry index holding the global table `_G` |
| `luaMaxInteger` | `(1 << 63) - 1` | Largest representable Lua integer |
| `luaMinInteger` | `-(1 << 63)` | Smallest representable Lua integer |

#### `luaUpvalueIndex(int i)`

Returns the pseudo-index for the upvalue at 1-based position `i`. Use this inside Dart callbacks to access upvalues pushed before the closure via `pushDartClosure` / `pushDartClosureAsync`.

---

### `LuaBasicAPI`

All stack manipulation, type queries, push/pop, table access, and load/call operations.

#### Stack Manipulation

```dart
int getTop()
```
Returns the index of the top element on the stack. Equivalent to the number of elements on the stack.

```dart
int absIndex(int idx)
```
Converts a possibly negative stack index to an absolute (positive) index.

```dart
bool checkStack(int n)
```
Ensures there are at least `n` free stack slots available. Returns `false` if the stack cannot grow.

```dart
void pop(int n)
```
Pops `n` elements from the top of the stack.

```dart
void copy(int fromIdx, int toIdx)
```
Copies the element at `fromIdx` to `toIdx` without removing the original.

```dart
void pushValue(int idx)
```
Pushes a copy of the element at `idx` onto the top of the stack.

```dart
void replace(int idx)
```
Moves the top element into position `idx`, popping it from the top.

```dart
void insert(int idx)
```
Inserts the top element at position `idx`, shifting elements above it upward.

```dart
void remove(int idx)
```
Removes the element at `idx`, shifting elements above it downward.

```dart
void rotate(int idx, int n)
```
Rotates the stack elements between `idx` and the top by `n` positions. Positive `n` rotates toward higher indices; negative rotates toward lower.

```dart
void setTop(int idx)
```
Sets the stack top to `idx`. If the new top is larger, new slots are filled with `nil`. If smaller, elements above are discarded.

#### Type Queries

```dart
String typeName(LuaType tp)
```
Returns the human-readable name of the given type (e.g., `"string"`, `"table"`).

```dart
LuaType type(int idx)
```
Returns the type of the value at stack position `idx`.

```dart
bool isNone(int idx)       // index is not valid
bool isNil(int idx)        // value is nil
bool isNoneOrNil(int idx)  // none or nil
bool isBoolean(int idx)    // value is a boolean
bool isInteger(int idx)    // value is an integer
bool isNumber(int idx)     // value is a number (int or float)
bool isString(int idx)     // value is a string
bool isTable(int idx)      // value is a table
bool isThread(int idx)     // value is a coroutine thread
bool isFunction(int idx)   // value is a Lua or Dart function
bool isDartFunction(int idx) // value is a registered Dart function
bool isUserdata(int idx)   // value is a userdata
```

#### Access Functions (Stack to Dart)

```dart
bool toBoolean(int idx)
```
Converts the value at `idx` to a boolean. Only `nil` and `false` are falsy; everything else is truthy.

```dart
int toInteger(int idx)
```
Converts the value at `idx` to an integer. Returns 0 if conversion fails.

```dart
int? toIntegerX(int idx)
```
Converts the value at `idx` to an integer. Returns `null` if conversion fails.

```dart
double toNumber(int idx)
```
Converts the value at `idx` to a floating-point number. Returns 0.0 if conversion fails.

```dart
double? toNumberX(int idx)
```
Converts the value at `idx` to a floating-point number. Returns `null` if conversion fails.

```dart
String? toStr(int idx)
```
Converts the value at `idx` to a string. Returns `null` if the value is not a string or number.

```dart
DartFunction? toDartFunction(int idx)
```
Extracts a registered synchronous Dart function from the stack. Returns `null` if the value is not a Dart function.

```dart
Object? toPointer(int idx)
```
Returns the light userdata pointer (a Dart object reference) at `idx`.

```dart
Userdata? toUserdata<T>(int idx)
```
Extracts a typed `Userdata<T>` from the stack. Returns `null` if the value is not a userdata.

```dart
int rawLen(int idx)
```
Returns the raw length of the value at `idx` without invoking metamethods. For strings, this is the byte length. For tables, it is the array length.

#### Push Functions (Dart to Stack)

```dart
void pushNil()
```
Pushes `nil` onto the stack.

```dart
void pushBoolean(bool b)
```
Pushes a boolean value.

```dart
void pushInteger(int? n)
```
Pushes an integer value. If `n` is `null`, pushes `nil`.

```dart
void pushNumber(double n)
```
Pushes a floating-point number.

```dart
void pushString(String? s)
```
Pushes a string. If `s` is `null`, pushes `nil`.

```dart
void pushFString(String fmt, [List<Object>? a])
```
Pushes a formatted string using a printf-like format string.

```dart
void pushDartFunction(DartFunction f)
```
Pushes a synchronous Dart function as a Lua-callable value.

```dart
void pushDartClosure(DartFunction f, int n)
```
Pushes a Dart closure with `n` upvalues. The upvalues must already be on the stack and are popped during closure creation.

```dart
void pushDartFunctionAsync(DartFunctionAsync f, [String? name])
```
Pushes an async Dart function as a Lua-callable value. The optional `name` is used in error messages.

```dart
void pushDartClosureAsync(DartFunctionAsync f, int n, [String? name])
```
Pushes an async Dart closure with `n` upvalues.

```dart
void pushGlobalTable()
```
Pushes the global environment table (`_G`) onto the stack.

#### Arithmetic and Comparison

```dart
void arith(ArithOp op)
```
Performs an arithmetic operation. For binary ops, pops two values and pushes the result. For unary ops (`luaOpUnm`, `luaOpBnot`), pops one value and pushes the result. Invokes metamethods when necessary.

```dart
bool compare(int idx1, int idx2, CmpOp op)
```
Compares the values at `idx1` and `idx2` using the given operator. Invokes metamethods when necessary.

```dart
bool rawEqual(int idx1, int idx2)
```
Returns `true` if the values at `idx1` and `idx2` are primitively equal, without invoking metamethods.

#### Table Operations

```dart
void newTable()
```
Creates a new empty table and pushes it onto the stack.

```dart
Userdata newUserdata<T>()
```
Creates a new typed userdata and pushes it onto the stack.

```dart
void createTable(int nArr, int nRec)
```
Creates a new table pre-allocated for `nArr` array entries and `nRec` hash entries, then pushes it.

```dart
LuaType getTable(int idx)
```
Pops a key from the stack top, then pushes `t[key]` (where `t` is the value at `idx`). Returns the type of the pushed value. Invokes `__index` metamethods.

```dart
LuaType getField(int idx, String? k)
```
Pushes `t[k]` onto the stack and returns its type. Invokes `__index`.

```dart
LuaType getI(int idx, int i)
```
Pushes `t[i]` using an integer key and returns its type. Invokes `__index`.

```dart
LuaType rawGet(int idx)
```
Like `getTable` but bypasses metamethods.

```dart
LuaType rawGetI(int idx, int i)
```
Like `getI` but bypasses metamethods.

```dart
LuaType getGlobal(String name)
```
Pushes `_G[name]` and returns its type.

```dart
bool getMetatable(int idx)
```
Pushes the metatable of the value at `idx`. Returns `false` if there is no metatable.

```dart
void setTable(int idx)
```
Pops a key and a value from the stack, then sets `t[key] = value`. Invokes `__newindex`.

```dart
void setField(int idx, String? k)
```
Pops a value from the stack and sets `t[k] = value`. Invokes `__newindex`.

```dart
void setI(int idx, int? i)
```
Pops a value and sets `t[i] = value` using an integer key. Invokes `__newindex`.

```dart
void rawSet(int idx)
```
Like `setTable` but bypasses metamethods.

```dart
void rawSetI(int idx, int i)
```
Like `setI` but bypasses metamethods.

```dart
void setMetatable(int idx)
```
Pops a table from the stack and sets it as the metatable of the value at `idx`.

```dart
void setGlobal(String name)
```
Pops a value from the stack and sets `_G[name] = value`.

```dart
void register(String name, DartFunction f)
```
Registers a synchronous Dart function as a global: `_G[name] = f`.

```dart
void registerAsync(String name, DartFunctionAsync f)
```
Registers an async Dart function as a global: `_G[name] = f`.

#### Load and Call

```dart
ThreadStatus load(Uint8List chunk, String chunkName, String? mode)
```
Loads a Lua chunk (source or binary). The `mode` parameter controls accepted formats: `"b"` for binary only, `"t"` for text only, or `null`/`"bt"` for both. On success, pushes the compiled closure onto the stack and returns `luaOk`.

```dart
void call(int nArgs, int nResults)
```
Calls a function. The function and its `nArgs` arguments must be on the stack. Results replace the function+args on the stack. Pass `luaMultret` for `nResults` to receive all return values.

```dart
ThreadStatus pCall(int nArgs, int nResults, int msgh)
```
Protected call. Like `call`, but catches errors and returns a `ThreadStatus`. The `msgh` parameter is the stack index of a message handler function (0 for none). On error, pushes the error object instead of results.

```dart
Future<void> callAsync(int nArgs, int nResults)
```
Async version of `call`. Use this when the function being called (or any function in its call chain) might be an async Dart function.

```dart
Future<ThreadStatus> pCallAsync(int nArgs, int nResults, int msgh)
```
Async protected call. Combines the error handling of `pCall` with async execution.

#### Miscellaneous

```dart
void len(int idx)
```
Pushes the length of the value at `idx`, invoking the `__len` metamethod for tables and userdata.

```dart
void concat(int n)
```
Concatenates the top `n` values on the stack using the `..` operator (invokes `__concat` metamethods if needed). Pops the values and pushes the result.

```dart
bool next(int idx)
```
Pops a key from the stack and pushes the next key-value pair from the table at `idx`. Returns `false` when there are no more entries.

```dart
int error()
```
Raises a Lua error using the value at the top of the stack as the error object.

```dart
bool stringToNumber(String s)
```
Attempts to parse `s` as a number. On success, pushes the number and returns `true`. Returns `false` if parsing fails.

---

### `LuaAuxLib`

Higher-level convenience methods layered on top of `LuaBasicAPI`.

#### Error Reporting

```dart
int error2(String fmt, [List<Object?>? a])
```
Raises a formatted error. Equivalent to `error(string.format(fmt, ...))`.

```dart
int argError(int arg, String extraMsg)
```
Raises an error describing a problem with argument `arg`, including the extra message.

#### Argument Checking

These methods validate function arguments, raising an error if the check fails.

```dart
void checkStack2(int sz, String msg)   // Ensures room for sz more slots
void argCheck(bool? cond, int arg, String extraMsg) // Raises argError if cond is false
void checkAny(int arg)                 // Ensures argument arg is present
void checkType(int arg, LuaType t)     // Ensures argument arg is of type t
int? checkInteger(int arg)             // Returns integer at arg, or errors
double? checkNumber(int arg)           // Returns number at arg, or errors
String? checkString(int arg)           // Returns string at arg, or errors
```

Optional argument accessors return a default when the argument is absent:

```dart
int? optInteger(int arg, int? d)
double? optNumber(int arg, double d)
String? optString(int arg, String d)
```

#### Load and Execute

```dart
bool doFile(String filename)
bool doString(String str)
```
Load and execute a Lua file or string synchronously. Returns `true` on success.

```dart
Future<bool> doFileAsync(String filename)
Future<bool> doStringAsync(String str)
```
Async counterparts. Use these when the code might call async Dart functions.

```dart
ThreadStatus loadFile(String? filename)
ThreadStatus loadFileX(String? filename, String? mode)
ThreadStatus loadString(String s)
```
Load a file or string without executing it. The compiled closure is pushed onto the stack. `loadFileX` accepts an explicit `mode` (`"b"`, `"t"`, or `null` for both).

#### Library Registration

```dart
void openLibs()
```
Opens all standard libraries (base, math, string, table, os, coroutine, package, utf8).

```dart
void requireF(String modname, DartFunction openf, bool glb)
```
Registers a module, similar to Lua's built-in `require` mechanism. If `glb` is `true`, the module is also stored as a global variable.

```dart
void newLib(Map<String, DartFunction?> l)
```
Creates a new library table from the given map and pushes it onto the stack.

```dart
void newLibTable(Map<String, DartFunction> l)
```
Creates a pre-sized table for a library (without registering functions).

```dart
void setFuncs(Map<String, DartFunction?> l, int nup)
```
Registers functions from the map into the table at the top of the stack, with `nup` upvalues shared across all functions.

#### Metatables

```dart
bool newMetatable(String tname)
```
Creates a new metatable stored in the registry under key `tname`. Returns `false` if it already exists.

```dart
void setMetatableAux(String tname)
```
Sets the named registry metatable on the table at the top of the stack.

```dart
LuaType getMetatableAux(String tname)
```
Pushes the named metatable from the registry.

```dart
LuaType getMetafield(int obj, String e)
```
Pushes the metafield `e` of the object at `obj`. Returns `luaNone` if the field doesn't exist.

```dart
bool callMeta(int obj, String e)
```
Calls the metamethod `e` on the object at `obj`. Returns `false` if no such metamethod exists.

#### References

```dart
int ref(int t)
```
Creates a reference to the value at the top of the stack in the table at index `t`. Pops the value and returns an integer reference key.

```dart
void unRef(int t, int ref)
```
Releases a reference previously created by `ref`.

#### Utilities

```dart
String typeName2(int idx)
```
Returns the type name of the value at `idx`.

```dart
String? toString2(int idx)
```
Returns the string representation of the value at `idx`.

```dart
int? len2(int idx)
```
Returns the length of the value at `idx`, respecting metamethods.

```dart
bool getSubTable(int idx, String fname)
```
Gets or creates a sub-table at `t[fname]`. Returns `true` if the table already existed.

---

### `LuaCoroutineLib`

Thread and coroutine management.

```dart
LuaState newThread()
```
Creates a new coroutine thread sharing the global environment. Pushes the thread onto the parent's stack and returns it.

```dart
LuaState? toThread(int idx)
```
Converts the value at `idx` to a thread. Returns `null` if it is not a thread.

```dart
void pushThread(LuaState L)
```
Pushes the thread `L` onto the stack.

```dart
void xmove(LuaState from, int n)
```
Moves `n` values from the `from` state's stack to `this` state's stack.

```dart
Object? popObject()
```
Pops and returns the top value as a raw Dart object.

```dart
void resume(int nArgs)
```
Resumes a suspended coroutine with `nArgs` arguments on the stack.

```dart
Future<void> resumeAsync(int nArgs)
```
Asynchronously resumes a suspended coroutine. Async calls inside the coroutine body are awaited transparently.

```dart
Future<void> callCoroutineAsync(int nArgs)
```
Async counterpart of `call` for the first invocation of a coroutine. Sets the `_insideResumeAsync` flag so that host async functions called via plain `CALL` (without explicit `await`) inside the coroutine body are transparently awaited.

```dart
void setStatus(ThreadStatus status)
ThreadStatus getStatus()
```
Get or set the coroutine's status.

```dart
int runningId()
```
Returns the unique ID of the currently running thread.

```dart
String debugThread()
```
Returns debug information about all threads.

```dart
void clearThreadWeakRef()
```
Clears weak references to dead threads.

```dart
int getCurrentNResults()
```
Gets the number of expected results for the current closure.

```dart
void resetTopClosureNResults(int nResults)
```
Resets the expected result count for the top closure.

```dart
String traceStack()
```
Returns a stack trace string for debugging.

```dart
void popStackFrame()
```
Pops the top stack frame (used after a yield is caught).

---

### `LuaDebug`

```dart
void setHook(HookContext context)
```
Sets a debug hook that fires when execution reaches the specified file and line.

#### `HookContext`

```dart
class HookContext {
  int hookId;
  int line;
  String fileName;
  Function hookFunction;

  HookContext(this.hookId, this.line, this.fileName, this.hookFunction);
  bool isHooked(String fileName, int line);
  void triggerHook();
}
```

---

### `Userdata<T>`

A typed userdata wrapper with per-instance metatable support and GC integration.

```dart
class Userdata<T> {
  LuaTable? metatable;
  T? get data;
  set data(T? value);
  int get estimatedSize;  // always 64
}
```

The generic parameter `T` allows the host to store any typed Dart data inside a Lua userdata. Each `Userdata` instance has its own metatable (unlike the shared-per-type approach in some other Lua implementations).

---

### `LuaYieldException`

```dart
class LuaYieldException implements Exception {
  final int nResults;
}
```

Internal exception thrown by `coroutine.yield()`. Caught by the coroutine resume machinery to implement cooperative multitasking. You generally do not need to interact with this type directly.

---

### `PlatformServices`

Abstract singleton that isolates platform-specific operations (file I/O, process execution, environment access) so that Luax can run on both native and web platforms.

```dart
PlatformServices.get instance   // Auto-initializing singleton accessor
void PlatformServices.init(PlatformServices services)  // Override with a custom implementation
void PlatformServices.reset()  // Reset the singleton (for testing)
```

| Member | Description |
|---|---|
| `void Function(String) printCallback` | Customizable print output callback |
| `void defaultPrint(String s)` | Platform-native print |
| `void println(String s)` | Print with newline |
| `String? getEnvironmentVariable(String name)` | Read an environment variable |
| `bool fileExists(String path)` | Check file existence |
| `bool directoryExists(String path)` | Check directory existence |
| `Uint8List? readFileAsBytes(String path)` | Read file as bytes |
| `String? readFileAsString(String path)` | Read file as string |
| `bool deleteFile(String path)` | Delete a file |
| `bool renameFile(String oldPath, String newPath)` | Rename a file |
| `String get pathSeparator` | Platform path separator (`/` on web, platform-dependent on native) |
| `int? runProcess(String command, List<String> args)` | Run a process synchronously |
| `Never exit(int code)` | Exit the process |
| `bool get isWeb` | Whether running on a web platform |
| `bool get isNative` | Whether running on a native platform |
| `bool get supportsFileSystem` | Whether file operations are available |
| `bool get supportsProcess` | Whether process operations are available |

On native platforms, `NativePlatformServices` delegates to `dart:io`. On web, `WebPlatformServices` provides stub implementations that return `null`/`false` for file operations and route `print` to the browser console.

---

### `LuaStateDebug` Extension

Defined in `lib/debug.dart`. Adds a convenience method for stack inspection during development.

```dart
extension LuaStateDebug on LuaState {
  void printStack();
}
```

Prints a formatted dump of the entire Lua stack to the console, showing index, type, and value for each stack slot.

---

### Parser API (`lua_parser.dart`)

The parser is exposed as a separate library for static analysis tools. Import with `import 'package:luax/lua_parser.dart';`.

#### `Parser`

```dart
class Parser {
  static Block parse(String chunk, String chunkName);
}
```

Parses a Lua source string into a `Block` AST node. Throws a syntax error if the source is invalid.

#### AST Node Hierarchy

All AST nodes extend the abstract `Node` base class, which carries `line` and `lastLine` source position fields.

**`Block`** -- A sequence of statements with an optional return expression list.

```dart
class Block extends Node {
  List<Stat> stats;
  List<Exp>? retExps; // null = no return; [] = bare "return"; non-empty = "return exprs"
}
```

**Expression nodes (`Exp`):**

| Node | Description | Key Fields |
|---|---|---|
| `NilExp` | `nil` literal | — |
| `TrueExp` | `true` literal | — |
| `FalseExp` | `false` literal | — |
| `VarargExp` | `...` | — |
| `IntegerExp` | Integer literal | `int val` |
| `FloatExp` | Float literal | `double val` |
| `StringExp` | String literal | `String str` |
| `NameExp` | Variable reference | `String name` |
| `UnopExp` | Unary operation | `TokenKind op`, `Exp exp` |
| `BinopExp` | Binary operation | `TokenKind op`, `Exp exp1`, `Exp exp2` |
| `ConcatExp` | String concatenation chain | `List<Exp> exps` |
| `TableConstructorExp` | Table constructor `{...}` | `List<Exp?> keyExps`, `List<Exp> valExps` |
| `FuncDefExp` | Function definition | `List<String> parList`, `bool isVararg`, `Block block` |
| `ParensExp` | Parenthesized expression | `Exp exp` |
| `TableAccessExp` | Table access `t[k]` | `Exp prefixExp`, `Exp keyExp` |
| `FuncCallExp` | Function call | `Exp prefixExp`, `StringExp? nameExp`, `List<Exp> args` |
| `AwaitExp` | `await <call>` (Luax extension) | `FuncCallExp inner` |

**Statement nodes (`Stat`):**

| Node | Description | Key Fields |
|---|---|---|
| `EmptyStat` | Empty statement `;` | — |
| `BreakStat` | `break` | — |
| `LabelStat` | `::name::` label | `String name` |
| `GotoStat` | `goto name` | `String name` |
| `DoStat` | `do ... end` block | `Block block` |
| `FuncCallStat` | Function call as statement | `Exp exp` |
| `WhileStat` | `while ... do ... end` | `Exp exp`, `Block block` |
| `RepeatStat` | `repeat ... until ...` | `Block block`, `Exp exp` |
| `IfStat` | `if/elseif/else` chain | `List<Exp> exps`, `List<Block> blocks` |
| `ForNumStat` | Numeric `for` loop | `String varName`, `Exp initExp`, `Exp limitExp`, `Exp stepExp`, `Block block` |
| `ForInStat` | Generic `for ... in ...` | `List<String> nameList`, `List<Exp> expList`, `Block block` |
| `LocalVarDeclStat` | `local a, b = ...` | `List<String> nameList`, `List<Exp> expList` |
| `AssignStat` | Assignment `a, b = x, y` | `List<Exp> varList`, `List<Exp> expList` |
| `LocalFuncDefStat` | `local function name() ... end` | `String name`, `FuncDefExp exp` |
