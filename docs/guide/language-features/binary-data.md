---
title: "Binary Data"
description: "string.pack / unpack / packsize for binary data manipulation"
outline: [2, 3]
library: "language-features"
---

# Binary Data

`string.pack`, `string.unpack`, and `string.packsize` for binary data
manipulation. Useful for network protocols, file formats, and any time you
need to read or write structured bytes.

## A first example

```lua
local packed = string.pack(">i4i4", 100, 200)
local a, b = string.unpack(">i4i4", packed)
print(a, b)  -- 100  200
```

`">i4i4"` is a *format string*: `>` says "big-endian", then `i4` is a
4-byte signed integer, repeated twice.

## Format specifiers

The format string is a sequence of single-letter options, each optionally
followed by a count. The first character may be one of:

| Flag | Effect |
|---|---|
| `<` | Little-endian (default) |
| `>` | Big-endian |
| `=` | Native endianness (default if no flag) |
| `!n` | Align to `n`-byte boundary (1, 2, 4, or 8) |

The remaining characters are format specifiers, possibly with a count:

| Spec | Size | Description |
|---|---|---|
| `x` | 1 | A single zero byte (padding) |
| `X` | 1 | One byte, "back" (skip a byte when unpacking) |
| `b` | 1 | A signed byte |
| `B` | 1 | An unsigned byte |
| `h` | 2 | A signed `short` |
| `H` | 2 | An unsigned `short` |
| `l` | 4 (native `int`) | A signed `long` |
| `L` | 4 (native `unsigned int`) | An unsigned `long` |
| `j` | 8 (native `size_t`) | A signed `size_t` |
| `J` | 8 (native `size_t`) | An unsigned `size_t` |
| `i` | 4 (default `int`) | A signed `int` |
| `I` | 4 (default `unsigned int`) | An unsigned `int` |
| `f` | 4 (native `float`) | A single-precision float |
| `d` | 8 (native `double`) | A double-precision float |
| `n` | 2 (Lua number) | A Lua number |
| `cn` | n | A fixed-size string of `n` bytes |
| `s` | variable | A zero-terminated string |
| `z` | variable | Same as `s` |

The integer specifiers can be followed by a count to override the default
size. For example, `i1` is a 1-byte signed int, `i2` is a 2-byte signed
short, `i8` is an 8-byte signed long.

## `string.unpack`

`string.unpack` returns the values, plus the position right after the last
read byte. This makes it easy to walk a binary structure:

```lua
local function read_header(bytes)
  local magic, version, body_length =
      string.unpack("<c4BI2", bytes)
  -- c4 = 4-byte string, B = 1-byte uint, I2 = 2-byte uint
  local offset = 1 + 4 + 1 + 2
  return magic, version, body_length, bytes:sub(offset)
end
```

## `string.packsize`

`string.packsize(fmt)` returns the size of the resulting packed string, *in
the same way `string.pack` would* — useful for allocating buffers:

```lua
local size = string.packsize(">i4i4")  -- 8
local buf = string.rep("\0", size)
-- ...fill buf...
local a, b = string.unpack(">i4i4", buf)
```

`packsize` ignores the variable-length specifiers (`s` and `z`).
