---
title: "Pattern Matching"
description: "Lua 5.3 pattern matcher ported from the reference C implementation, with %b and %f support"
outline: [2, 3]
library: "language-features"
---

# Pattern Matching

The pattern matcher is ported from the reference Lua 5.3 C implementation,
including support for `%b` (balanced match) and `%f` (frontier pattern).
Luax does **not** use a regex translator — it's a faithful port of
[`lstrlib.c`](https://www.lua.org/source/5.3/lstrlib.html), so behavior
matches upstream Lua 5.3 in every documented edge case.

## Functions

The `string` library exposes the standard pattern-matching functions:

| Function | Description |
|---|---|
| `string.find(s, pattern, init, plain)` | Find the first match; returns start, end, and captures |
| `string.match(s, pattern, init)` | Return the captures of the first match |
| `string.gmatch(s, pattern, init)` | Iterator over all matches |
| `string.gsub(s, pattern, repl, n)` | Global substitution; returns the new string and replacement count |

## Balanced matches `%b`

`%b(xy)` matches a substring that starts with `x`, ends with `y`, and is
balanced — the inner `x`s and `y`s cancel out:

```lua
-- Balanced parentheses matching
print(string.match("(hello (world))", "%b()"))  -- (hello (world))

-- Balanced square brackets
print(string.match("[a[b]c[d]e]", "%b[]"))     -- [a[b]c[d]e]
```

The opening and closing characters must be two distinct single-byte
characters. Use `string.find` with `init` to skip ahead when scanning a
larger string:

```lua
local code = "if (x) { if (y) { z; } }"
local i = 1
while true do
  local s, e = string.find(code, "%b()", i)
  if not s then break end
  print(s, e, code:sub(s, e))
  i = e + 1
end
```

## Frontier patterns `%f`

`%f[set]` matches an empty string at the frontier where the previous
character is *not* in `set` and the next character *is*. Useful for matching
at word boundaries (or any other character class transition):

```lua
-- Frontier pattern (word boundaries)
for w in string.gmatch("hello world", "%f[%a]%a+") do
  print(w)  -- "hello", "world"
end
```

`%f[%a]` matches at any transition from a non-letter to a letter. This is
more reliable than `\b` in regex because it works correctly at the start and
end of the string (where the "previous character" is the imaginary `\0`
sentinel).

## Common character classes

| Class | Matches |
|---|---|
| `%a` | Letters |
| `%d` | Digits |
| `%w` | Alphanumeric (`%a` + `%d`) |
| `%s` | Whitespace |
| `%p` | Punctuation |
| `%c` | Control characters |
| `%x` | Hex digits |
| `%z` | The null byte (`\0`) |
| `%u` | Uppercase letters |
| `%l` | Lowercase letters |
| Uppercase version | Complement (e.g. `%A` = non-letters) |

## Captures

A pattern can have zero or more *captures* — sub-patterns wrapped in
parentheses. Captures are returned by `match`/`gmatch` and substituted by
`gsub` using `%1` through `%9`:

```lua
local name, age = string.match("Alice (24)", "(%a+) %((%d+)%)")
print(name, age)  -- Alice  24

print(string.gsub("hello world", "(%w+)", "[%1]"))
-- [hello] [world]   2
```

Use `%0` in a `gsub` replacement to refer to the entire match.

## When *not* to use patterns

Patterns are great for small, structured text work — log lines, simple
formats, tokenization. For real parsing, reach for a proper parser; see the
[Parser & AST guide](../parser-ast.md).
