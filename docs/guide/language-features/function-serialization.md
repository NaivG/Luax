---
title: "Function Serialization"
description: "string.dump serializes compiled Lua functions to the Lua 5.3 binary chunk format"
outline: [2, 3]
library: "language-features"
---

# Function Serialization

`string.dump` serializes compiled Lua functions to the standard Lua 5.3
binary chunk format. The serialized bytes can be written to disk, sent over
the network, or stored in a database — and re-loaded with `load` on any
Lua 5.3-compatible VM, including Luax.

## Basic usage

```lua
local f = load("return 1 + 2")
local bytes = string.dump(f)
local f2 = load(bytes)
print(f2())  -- 3
```

`string.dump` is the inverse of `load` for binary chunks. It's the standard
way to precompile Lua source, ship it as bytes, and avoid the parse-and-compile
step on the receiving end.

## Precompiling at build time

For server apps, a common pattern is to precompile `.lua` files to `.luac`
files at build time and load the compiled version at runtime:

```bash
# Precompile (using upstream luac or any Lua 5.3 compatible compiler)
luac -o config.luac config.lua
```

```lua
-- At runtime
local f = assert(loadfile("config.luac"))
f()
```

Luax's `loadfile` accepts both source and precompiled chunks — it
auto-detects the format by the file header. See
[`LuaAuxLib.loadFile`](/api/lua/LuaAuxLib#loadfile).

## What about closures and upvalues?

`string.dump` captures the *function body* but **not** the closure's
environment or upvalues. When you reload the dumped function, the new
function has no upvalues of its own — its environment is whatever global
table is in scope at `load` time.

```lua
local x = 10
local f = function() return x end
local bytes = string.dump(f)

-- Reload in a fresh environment
x = 999
local f2 = load(bytes)()
print(f2())  -- 10 (captured the original x)
```

If you need to preserve upvalues, you must serialize them separately and
re-bind them after `load`.

## Stripping debug info

`string.dump` accepts a second `strip` argument. If `true`, the function's
debug info (line numbers, local variable names, source filename) is removed
from the output. This produces a smaller, more opaque binary chunk:

```lua
local bytes = string.dump(f, true)  -- strip debug info
```

The stripped function can still be called, but `debug.getinfo` will return
limited information for it. Use this when shipping precompiled code to
untrusted environments.
