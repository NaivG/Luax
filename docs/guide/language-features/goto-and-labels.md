---
title: "Goto / Label"
description: "Lua 5.2+ goto and ::label:: syntax with proper upvalue closing and shadowing"
outline: [2, 3]
library: "language-features"
---

# Goto / Label

Full support for Lua 5.2+ `goto` and `::label::` syntax, including proper
upvalue closing and same-name label shadowing.

## Basic syntax

```lua
for i = 1, 10 do
  for j = 1, 10 do
    if i * j > 50 then
      goto done
    end
    print(i, j)
  end
end
::done::
print("Finished!")
```

A label is a double-colon-prefixed identifier followed by another pair of
double colons: `::name::`. `goto name` jumps to the label.

## Use cases

`goto` is the right tool for breaking out of nested loops cleanly, and for
implementing state machines. It's *not* a general replacement for structured
control flow — most code should stick to `if`/`while`/`for`/`repeat`.

### Breaking out of nested loops

```lua
for i = 1, 100 do
  for j = 1, 100 do
    if someCondition(i, j) then
      goto found
    end
  end
end
::found::
print("done")
```

### Simple state machines

```lua
local state = "init"
while true do
  if state == "init" then
    setup()
    state = "running"
  elseif state == "running" then
    local done = step()
    if done then state = "cleanup" end
  elseif state == "cleanup" then
    teardown()
    state = nil
  end
  if state == nil then
    goto end
  end
end
::end::
```

## Scoping rules

`goto` cannot jump into the scope of a local variable, nor out of a function
or a block that defines local variables that are live at the jump target:

```lua
goto foo  -- ERROR: cannot jump into a local's scope
local x  -- ← x is not in scope at the goto

::foo::
print(x)
```

`goto` *can* jump out of a block (the locals defined inside are closed
properly):

```lua
do
  local file = io.open(path)
  if not file then
    goto done  -- local `file` is closed properly
  end
  file:read("*a")
  file:close()
end
::done::
```

## Upvalue closing

When a `goto` jumps out of a closure's enclosing scope, the closure's upvalues
are closed in the correct order — matching the standard Lua 5.3 semantics.
This is critical for code that uses `goto` to escape a function-with-cleanup
pattern, especially with coroutines.
