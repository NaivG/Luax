---
title: "Language Features"
description: "Lua 5.3 language features supported by Luax — beyond the Lua 5.1 baseline"
outline: [2, 3]
library: "guide"
---

# Language Features

Luax is a Lua 5.3 VM, so all standard Lua 5.3 features are available. This
section covers the parts of Lua 5.3 that go beyond the "Lua 5.1 with patches"
baseline — features that are sometimes surprising if you've only used older
Lua versions, or that benefit from being highlighted explicitly.

## Lua 5.3+ highlights

<div grid="cols-2" gap="16">

- ### [Goto / Label](goto-and-labels.md)

  Full Lua 5.2+ `goto` and `::label::` syntax with proper upvalue closing and
  same-name label shadowing.

- ### [Pattern Matching](pattern-matching.md)

  The reference Lua 5.3 pattern matcher, ported to Dart, including `%b`
  (balanced match) and `%f` (frontier pattern).

- ### [Binary Data](binary-data.md)

  `string.pack`, `string.unpack`, and `string.packsize` for binary data
  manipulation.

- ### [Function Serialization](function-serialization.md)

  `string.dump` serializes compiled Lua functions to the standard binary
  chunk format.

</div>

## Other Lua 5.3 features

The above pages focus on the language features most likely to surprise or
delight. Other Lua 5.3 features — integers, bitwise operators, the new
integer division operator `//`, the `~` unary, UTF-8 string support — are
implemented in Luax and covered in the [Standard Library
reference](/reference/standard-library/).

For the underlying language surface, see the [Lua 5.3
manual](https://www.lua.org/manual/5.3/). Luax does not introduce any
incompatible syntax or semantics relative to standard Lua 5.3, with two
notable exceptions:

- **`await` is a reserved keyword** (added in Luax 0.3.1). It is only
  meaningful as a prefix to a function call expression. See the
  [Async / Await guide](../async-await.md).
- **`event` is a global table** that is always loaded by `openLibs()`. If you
  need a Lua environment without the event system, call `openLib` on the
  specific libraries you want.
