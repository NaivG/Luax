---
title: "Luax Standard Library Manual"
description: "Every function provided by the Luax standard libraries — string, math, table, os, coroutine, utf8, and more"
outline: [2, 3]
library: "reference"
---

# Luax Standard Library Manual

This document covers every function provided by the Luax standard libraries,
which are loaded by calling `state.openLibs()`. The libraries conform to
Lua 5.3 semantics, with a few Luax-specific extensions noted where
applicable.

For a quick reference of just the Dart-side API, see
[`/api/lua/`](/api/lua/). For a more in-depth treatment of specific
language features, see the [Guide](/guide/).

## Basic Library (Global Functions)

These functions are available globally without any prefix.

### `print(...)`

Prints all arguments to stdout, separated by tabs and terminated by a
newline. Each argument is converted via `tostring`. Output is routed
through `PlatformServices.instance.printCallback`, which can be redirected
by the host application.

```lua
print("hello", 42, true)  --> hello	42	true
```

### `assert(v [, message])`

If `v` is truthy, returns all its arguments. Otherwise, raises an error
with `message` (or `"assertion failed!"` if no message is given).

```lua
local x = assert(io.open("file.txt"), "file not found")
```

### `error(message [, level])`

Raises an error with `message` as the error object. The optional `level`
parameter controls how much stack trace information is added (level 1 adds
the caller's position, level 2 adds the caller's caller, etc.).

```lua
error("something went wrong")
error("bad argument", 2)
```

### `pcall(f [, arg1, ...])`

Calls function `f` with the given arguments in protected mode. Returns
`true` followed by the function's results on success, or `false` followed
by the error message on failure.

```lua
local ok, result = pcall(function() return 42 end)
-- ok = true, result = 42

local ok, err = pcall(function() error("boom") end)
-- ok = false, err = "boom"
```

### `xpcall(f, msgh [, arg1, ...])`

Like `pcall`, but accepts a message handler function `msgh`. On error,
`msgh` is called with the raw error value and its return value becomes
the error object returned to the caller.

```lua
local ok, err = xpcall(risky_function, function(e)
    return "handled: " .. tostring(e)
end)
```

### `select(index, ...)`

If `index` is the string `"#"`, returns the number of remaining arguments.
Otherwise, returns all arguments from position `index` onward. Negative
indices count from the end.

```lua
select(2, "a", "b", "c")  --> "b", "c"
select("#", "a", "b", "c") --> 3
```

### `type(v)`

Returns the type of `v` as a string: `"nil"`, `"boolean"`, `"number"`,
`"string"`, `"table"`, `"function"`, `"thread"`, or `"userdata"`.

### `tostring(v)`

Converts `v` to a string representation. Respects the `__tostring`
metamethod if present.

### `tonumber(e [, base])`

Converts `e` to a number. Without `base`, handles standard numeric
conversion including hex floats. With `base` (2-36), parses the string in
that radix. Strips `0x`/`0X` prefix for base 16.

```lua
tonumber("0xFF")       --> 255
tonumber("1010", 2)    --> 10
tonumber("hello")      --> nil
```

### `ipairs(t)`

Returns an iterator function, the table `t`, and `0` as the initial
control variable. Iterates over integer keys `1, 2, 3, ...` until a nil
value is found.

```lua
for i, v in ipairs({"a", "b", "c"}) do
    print(i, v)  --> 1 a  /  2 b  /  3 c
end
```

### `pairs(t)`

Returns `next, t, nil` — or calls the `__pairs` metamethod if present.
Use this to iterate over all keys in a table.

```lua
for k, v in pairs({x=1, y=2}) do
    print(k, v)
end
```

### `next(table [, index])`

Returns the next key-value pair in the table after `index`. Pass `nil`
(or omit) for `index` to get the first pair. Returns `nil` when there
are no more entries.

### `getmetatable(object)`

Returns the object's metatable, or the `__metatable` field if the
metatable has one. Returns `nil` if no metatable is set.

### `setmetatable(table, metatable)`

Sets `metatable` as the metatable of `table`. The `metatable` argument
must be `nil` or a table. If the current metatable has a `__metatable`
field, raises an error.

### `rawget(table, index)`

Gets `table[index]` without invoking metamethods.

### `rawset(table, index, value)`

Sets `table[index] = value` without invoking metamethods.

### `rawequal(v1, v2)`

Returns `true` if `v1` is primitively equal to `v2` (without metamethods).

### `rawlen(v)`

Returns the raw length of a table or string (without invoking `__len`).

### `load(chunk [, chunkname [, mode [, env]]])`

Loads a Lua chunk from a string. Detects binary chunks via the
`\x1BLua` magic header. The `mode` parameter controls accepted formats:
`"b"` for binary only, `"t"` for text only, `"bt"` for both (default).
Returns the compiled function on success, or `nil` plus an error message
on failure.

### `loadfile([filename [, mode [, env]]])`

Loads a Lua file without executing it. Returns the compiled function or
`nil` plus an error message. Not available on web platforms.

### `dofile([filename])`

Loads and immediately executes a Lua file. Returns all results from the
chunk. Not available on web platforms.

### `collectgarbage([opt [, arg]])`

Interfaces with the garbage collector. See the
[Garbage Collection guide](/guide/garbage-collection.md) for the full
table of supported options including the Luax-specific `"info"` mode.

### Global Values

| Name | Value | Description |
|---|---|---|
| `_G` | (the global table) | Self-reference to the global environment |
| `_VERSION` | `"Lua 5.3"` | Version string |

## Math Library

Access via the `math` table.

### Constants

| Constant | Value | Description |
|---|---|---|
| `math.pi` | 3.14159265358979... | The mathematical constant pi |
| `math.huge` | `inf` | Positive infinity |
| `math.maxinteger` | 9223372036854775807 (native) / 9007199254740991 (web) | Maximum integer value |
| `math.mininteger` | -9223372036854775808 (native) / -9007199254740991 (web) | Minimum integer value |

The integer bounds adapt to the platform: full 64-bit range on native
Dart, 53-bit safe integer range on web (JavaScript).

### Functions

```
math.abs(x)          -- Absolute value
math.ceil(x)         -- Smallest integer >= x
math.floor(x)        -- Largest integer <= x
math.fmod(x, y)      -- Truncation-based floating-point remainder
math.modf(x)         -- Returns integer part and fractional part
math.max(x, ...)     -- Maximum of all arguments
math.min(x, ...)     -- Minimum of all arguments
math.sqrt(x)         -- Square root
math.exp(x)          -- e raised to the power x
math.log(x [, base]) -- Logarithm (default: natural log)
math.deg(x)          -- Radians to degrees
math.rad(x)          -- Degrees to radians
math.sin(x)          -- Sine (radians)
math.cos(x)          -- Cosine (radians)
math.tan(x)          -- Tangent (radians)
math.asin(x)         -- Arcsine
math.acos(x)         -- Arccosine
math.atan(y [, x])   -- Arctangent (atan2 with x defaulting to 1.0)
```

### `math.random([m [, n]])`

Generates pseudo-random numbers. With no arguments, returns a float in
[0, 1). With one argument `m`, returns an integer in [1, m]. With two
arguments, returns an integer in [m, n] inclusive.

### `math.randomseed(x)`

Seeds the random number generator with `x`.

### `math.tointeger(x)`

Converts `x` to an integer if it is exactly representable as one,
otherwise returns `nil`.

### `math.type(x)`

Returns `"integer"` if `x` is an integer, `"float"` if `x` is a float,
or `nil` if `x` is not a number.

### `math.ult(m, n)`

Performs unsigned integer comparison. Returns `true` if `m < n` when
both are interpreted as unsigned integers.

## String Library

Access via the `string` table. Strings also have a metatable with
`__index = string`, enabling method-call syntax: `("hello"):upper()`.

### Basic Operations

```
string.len(s)                  -- Length of string s
string.sub(s, i [, j])         -- Substring from position i to j (default: -1)
string.rep(s, n [, sep])      -- Repeat string s, n times, with optional separator
string.reverse(s)              -- Reverse the string
string.lower(s)                -- Convert to lowercase
string.upper(s)                -- Convert to uppercase
```

Indices are 1-based and support negative values (counting from the end).

### Byte and Character Operations

```
string.byte(s [, i [, j]])
```

Returns the code unit values of characters from position `i` to `j`
(defaults: `i=1`, `j=i`).

```
string.char(...)
```

Creates a string from the given code unit values (0-255).

### Formatting

```
string.format(formatstring, ...)
```

Formats a string using printf-like specifiers. Supports: `%c`, `%d`,
`%i`, `%o`, `%u`, `%x`, `%X`, `%f`, `%e`, `%E`, `%g`, `%G`, `%s`, `%q`,
`%%`.

The `%q` specifier produces a double-quoted string with proper escaping
of `\`, `"`, `\n`, `\r`, `\0`, and `\26`.

Luax includes an optimized fast path (`useFastFormat`) that caches parsed
format strings and handles common specifiers (`%d`, `%i`, `%u`, `%s`,
`%c`, `%f`) inline without invoking the sprintf package.

### Binary Data

See the [Binary Data guide](../guide/language-features/binary-data.md) for
the full reference. The summary:

```
string.pack(fmt, v1, v2, ...)
string.unpack(fmt, s [, pos])
string.packsize(fmt)
```

Format characters supported:

| Char | Type | Size |
|---|---|---|
| `b` / `B` | Signed/unsigned byte | 1 |
| `h` / `H` | Signed/unsigned short | 2 |
| `i` / `I` | Signed/unsigned int | variable (default 4) |
| `l` / `L` | Signed/unsigned long | 8 |
| `j` / `J` | Lua integer | 8 |
| `f` | Float | 4 |
| `d` / `n` | Double | 8 |
| `s` | Length-prefixed string | variable |
| `z` | Null-terminated string | variable |
| `x` | Padding byte | 1 |

Endianness: `<` (little-endian), `>` or `!` (big-endian), `=` (host).

### Serialization

```
string.dump(function [, strip])
```

Serializes a Lua function (closure with a prototype) to a binary chunk
string. The optional `strip` flag removes debug information for smaller
output. The result can be reloaded via `load()`. See the
[Function Serialization guide](../guide/language-features/function-serialization.md)
for more.

### Pattern Matching

Luax implements a full port of reference Lua 5.3's pattern engine (not
regex-based). See the
[Pattern Matching guide](../guide/language-features/pattern-matching.md)
for a tutorial and examples.

Summary of the surface:

| Function | Description |
|---|---|
| `string.find(s, pattern [, init [, plain]])` | Find the first match |
| `string.match(s, pattern [, init])` | Return captured substrings |
| `string.gmatch(s, pattern)` | Iterator over all matches |
| `string.gsub(s, pattern, repl [, n])` | Global substitution |

## Table Library

Access via the `table` table.

```
table.insert(list, [pos,] value)
```

Inserts `value` into `list` at position `pos` (default: end of list),
shifting existing elements up. With two arguments, appends to the end.

```
table.remove(list [, pos])
```

Removes the element at position `pos` (default: last element), shifting
elements down. Returns the removed value.

```
table.sort(list [, comp])
```

Sorts the list in-place. The optional `comp` function receives two
elements and returns `true` if the first should come before the second.
The default comparison uses the `<` operator.

```
table.concat(list [, sep [, i [, j]]])
```

Concatenates the string/number elements of `list` from index `i` to `j`
(defaults: `i=1`, `j=#list`) with an optional separator. Elements must
be strings or numbers.

```
table.move(a1, f, e, t [, a2])
```

Moves elements from `a1[f..e]` to `a2[t..]` (or `a1[t..]` if `a2` is
omitted). Handles overlapping ranges correctly. Returns the destination
table.

```
table.pack(...)
```

Packs all arguments into a table `{[1]=arg1, [2]=arg2, ..., n=count}`,
where `n` is the number of arguments.

```
table.unpack(list [, i [, j]])
```

Returns `list[i]` through `list[j]` as multiple return values. Defaults:
`i=1`, `j=#list`. Maximum 1,000,000 elements.

## OS Library

Access via the `os` table. Some functions require file system or process
support and will return errors on web platforms — see the
[Web Platform guide](../guide/web-platform.md) for the full web limitations
table.

```
os.clock()
```

Returns elapsed CPU-approximate time in seconds (measured via a
`Stopwatch`).

```
os.time([table])
```

Without arguments, returns the current Unix timestamp (seconds since
epoch). With a table containing `year`, `month`, `day`, `hour`, `min`,
`sec` fields, constructs a `DateTime` and returns the corresponding
epoch seconds.

```
os.date([format [, time]])
```

Formats a date/time value. Default format is `"%c"`. Prefixing the
format with `"!"` uses UTC. Format `"*t"` returns a table with fields:
`sec`, `min`, `hour`, `day`, `month`, `year`, `wday`, `yday`.

Supported format specifiers: `%Y`, `%y`, `%m`, `%d`, `%H`, `%M`, `%S`,
`%A`, `%a`, `%B`, `%b`/`%h`, `%p`, `%I`, `%j`, `%w`, `%c`, `%x`, `%X`,
`%Z`, `%z`, `%%`, `%n`, `%t`.

```
os.difftime(t2, t1)
```

Returns `t2 - t1` (difference in seconds).

```
os.remove(filename)
```

Deletes a file. Returns `true` on success, or `nil` plus an error
message on failure. Requires file system support.

```
os.rename(oldname, newname)
```

Renames a file. Returns `true` on success, or `nil` plus an error
message on failure. Requires file system support.

```
os.getenv(varname)
```

Returns the value of the environment variable `varname`, or `nil` if
not set or empty.

```
os.execute([command])
```

Executes a shell command. Returns `true`/`false`, `"exit"`/`"signal"`,
and the exit code. Requires process support.

```
os.exit([code [, close]])
```

Exits the process with the given exit code. Accepts a boolean
(`true` = 0, `false` = 1) or an integer. On web platforms, this is a
no-op.

**Not implemented:** `os.tmpname()` and `os.setlocale()` are not yet
implemented and will raise errors.

## Coroutine Library

Access via the `coroutine` table. See the [Coroutines guide](../guide/coroutines.md)
for the full protocol and async support.

```
coroutine.create(f)
```

Creates a new coroutine with body function `f`. Returns the coroutine
(thread) object.

```
coroutine.resume(co [, val1, ...])
```

Starts or resumes coroutine `co`, passing the given values. Returns
`true` followed by yielded/returned values on success, or `false`
followed by an error message on failure.

```
coroutine.yield(...)
```

Suspends the running coroutine, passing the given values back to the
caller of `resume`.

```
coroutine.wrap(f)
```

Creates a coroutine and returns a wrapper function. Each call to the
wrapper resumes the coroutine and returns yielded/returned values
directly (without the boolean status prefix that `resume` provides).
Raises an error on failure.

```
coroutine.status(co)
```

Returns `"running"` if `co` is the currently executing coroutine,
`"suspended"` if it is yielded or not yet started, or `"dead"` if it
has finished or errored fatally.

```
coroutine.running()
```

Returns the currently running coroutine (thread object).

### Luax Extension: `coroutine.resumeAsync`

```
coroutine.resumeAsync(co [, val1, ...])   -- async
```

Async counterpart of `coroutine.resume`. Uses `await` internally to
support coroutine bodies that call host async functions registered via
`registerAsync`. Returns the same `(bool, ...)` tuple as `resume`.

This is the key extension enabling interop between Lua coroutines and
Dart `Future`-based async functions:

```lua
local co = coroutine.create(function()
    local data = fetchData("https://example.com")  -- async host function
    print(data)
end)

local ok, err = coroutine.resumeAsync(co)
```

Inside a coroutine resumed via `resumeAsync`, host async functions are
transparently awaited without requiring explicit `await` on each call.

## Package Library

The package system provides module loading via `require`.

```
require(modname)
```

Loads a module by name. Checks `package.loaded[modname]` first. If not
found, iterates through `package.searchers` to find a loader, calls it,
and stores the result.

### Package Fields

| Field | Description |
|---|---|
| `package.path` | Search path template: `"./?.lua;./?/init.lua"` |
| `package.loaded` | Table of already-loaded modules |
| `package.preload` | Table of preloaded module loaders |
| `package.searchers` | Array of searcher functions (preload searcher + Lua file searcher) |
| `package.config` | Configuration string (dir separator, path separator, etc.) |
| `package.cpath` | `nil` (C module loading is not supported) |

```
package.searchpath(name, path [, sep [, rep]])
```

Searches for `name` in the semicolon-separated `path` template,
replacing `sep` (default `"."`) with `rep` (default: OS directory
separator) and `?` with the module name. Returns the first path that
exists, or `nil` plus an error message.

File system operations are guarded by
`PlatformServices.instance.supportsFileSystem` and will fail gracefully
on web platforms.

## UTF-8 Library

Access via the `utf8` table. Provides basic UTF-8 encoding and decoding
operations.

```
utf8.char(...)
```

Converts one or more Unicode code points to a UTF-8 encoded string.

```
utf8.codepoint(s [, i [, j]])
```

Returns the Unicode code points of characters between code-unit
positions `i` and `j` (both 1-based, inclusive). Handles surrogate
pairs.

```
utf8.codes(s)
```

Returns an iterator producing `(position, codepoint)` pairs for all
Unicode characters in `s`. Positions are 1-based code-unit indices.

```
utf8.len(s [, i [, j]])
```

Returns the number of Unicode characters in `s` between code-unit
positions `i` and `j`. Returns `nil, position` if an invalid surrogate
sequence is encountered.

```
utf8.offset(s, n [, i])
```

Returns the code-unit position of the n-th Unicode character counting
from position `i`. Use `n=0` to find the start of the character
containing position `i`. Negative `n` counts backward.

```
utf8.charpattern
```

A Lua pattern string that matches exactly one UTF-8 byte sequence:
`[\0-\x7F\xC2-\xFD][\80-\xBF]*`.

## Pattern Matching Reference

Luax uses a custom pattern engine (ported from reference Lua 5.3's
`lstrlib.c`) rather than regular expressions. This section provides a
complete reference. See the
[Pattern Matching guide](../guide/language-features/pattern-matching.md) for
a tutorial.

### Character Classes

| Class | Matches |
|---|---|
| `%a` | Letters |
| `%A` | Non-letters |
| `%c` | Control characters |
| `%C` | Non-control characters |
| `%d` | Digits (0-9) |
| `%D` | Non-digits |
| `%g` | Printable characters except space |
| `%G` | Non-printable or space |
| `%l` | Lowercase letters |
| `%L` | Non-lowercase |
| `%p` | Punctuation |
| `%P` | Non-punctuation |
| `%s` | Whitespace |
| `%S` | Non-whitespace |
| `%u` | Uppercase letters |
| `%U` | Non-uppercase |
| `%w` | Alphanumeric |
| `%W` | Non-alphanumeric |
| `%x` | Hexadecimal digits |
| `%X` | Non-hexadecimal |

### Quantifiers

| Quantifier | Meaning |
|---|---|
| `*` | Zero or more (greedy) |
| `+` | One or more (greedy) |
| `-` | Zero or more (lazy) |
| `?` | Zero or one |

Quantifiers apply to the preceding character class, literal character,
or bracket set.

### Anchors

`^` anchors the match to the beginning of the string. `$` anchors to
the end. Both only work when placed at the start/end of the pattern.

### Special Patterns

`%bxy` matches a balanced pair: starting with character `x` and ending
with character `y`, with matching nesting. Example: `%b()` matches
balanced parentheses.

`%f[set]` is a frontier pattern: matches an empty string at a position
where the preceding character is not in `set` and the next character is
in `set`.

### Bracket Sets

`[abc]` matches any character in the set. `[a-z]` matches any character
in the range. `[^abc]` matches any character not in the set. Character
classes like `%d` can be used inside bracket sets.

### Captures

`()` captures the substring matched by the enclosed pattern. Empty `()`
captures the current position (as an integer). Up to 32 captures are
supported per pattern.

### Back-references

In `gsub` replacement strings, `%0` refers to the whole match, `%1`
through `%9` refer to captures, and `%%` produces a literal `%`.
