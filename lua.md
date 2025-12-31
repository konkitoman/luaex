# Lua Syntax

goto will not be included!

## Stack

or scope.

the default stack, is the global stack.

Variabiles defined in a stack, will not be accessibile in down stream stacks, but are visibile in upper stacks.

```lua
do
  -- this is a stack.
  do
    -- this is an stack, that is upper then previous, so can access anything that is down stream.
  end
  -- anything that was stored in that upper stack, now will be freed if are not used somewhere else.
end
```

- Any upper stack will depend on the down stream stacks variabiles.
- When a function stack is created will not be able to break or return for an down stream stack.
- When a loop stack is create will depend on the down stream stack return ability, and the break will be accessibile from the current to the upper stacks.
- When a do stack is create will depend on the down stream stack return, break ability.
- The module stack is a function stack, when we call `require(module)` is like calling that module.


when we do:
```lua
do
-- this is inside a new stack.
end
```

`do end` will always work like if true then end for the stack and has no condition to check.

```lua
while true do
-- this is inside a new loop stack.
  do

  end
end
```
```lua
function fn() -- stack s1
-- this is inside a new function stack.
  do -- stack s2
    return -- will return the s1 stack
  end
end
```

## Defining and Set

Some stuff on how defining, setting and the stack works.

If we have:
```lua
do
a = 32 -- this will set the upper most variabile a to 32, if is not defined in any down stream stack a global will be created.
local a; -- `a` now is defined in the current stack.
assert(a == nil) -- the value of `a` is `nil`, because this is a new a, the value of the other a will be avalibile when this stack ends.
a = 10
assert(a == 10) -- now the value of `a` is 10.
local a;
assert(a == nil) -- now `a` is nil again, in this case there is now way to get the value to the previous `a`,
-- so I think when we define `a` variabile in lua after is defined then will be set to `nil`, if is shadowed there is now way
-- to get the previous variabile.
end
assert(a == 32) -- `a` is 32 because this is the global `a`
```

```lua
local a -- `a` now is defined in the current stack.
```

```lua
local a = 32 -- `a` now is defined and set in the current stack.
```

```lua
local a, b -- `a`, `b` now is defined in the current stack.
```

```lua
local a, b = 1, 2 -- `a` = 1, `b` = 2 now is defined and set in the current stack.
-- the set value is a tuple
```

```lua
local a, b = 1, a + 2 -- this is invalid because `a` was not defined and not set.
```

```lua
local a, b
a, b = 1, a + 2 -- this is invalid because `a` was not set to 1.
```

```lua
local a, b = 2
a, b = 1, a + 2 -- this will result in `a = 1` and `b = 4`,
-- What is after = is evaluated first then after the resulting tuple the `a` and `b` will be set.
```

```lua
f.a = 2 -- set the `a` inside the `f` table
```

```lua
f.a.b = 2 -- set the `b` inside the `a` table, inside the `f` table
```

```lua
f["a"] = 2 -- set the `a` inside the `f` table
```

```lua
f["a"]["b"] = 2 -- set the `b` inside the `a` table, inside the `f` table
```

```lua
function fn() -- will define and set a global function, can call itself.
end
```

```lua
local function fn() -- will define and set a function in this stack, can call itself.
end
```

```lua
fn = function() -- this will try to set the up most fn variabile, if cannot do that will set a global, can call itself.
end
```

```lua
a.fn = function() -- this will set the `fn` inside the `a` table.
end
```

```lua
a["fn"] = function() -- this will set the `fn` inside the `a` table.
end
```

```lua
local fn = function() -- will set and then define a function in this stack, cannot has access to itself.
end
```

```lua
local fn -- define
fn = function() -- will set a function in, can call itself.
end
```

```lua
function a.fn() -- this will define and set a function inside `a` table.
end
```

```lua
function a.b.fn() -- this will define and set a function inside `b` table, inside the `a` table.
end
```

```lua
function a:fn() -- this will define and set a function inside `a` table, that will have a variabile inside it called `self`,
-- is the first argument to the function when is called.
end
```
## Calling

When you call a function you need to specifi the function object, a table can be a function object, if has set a metatable with `__call`.
You call a function by using brackets `()` between the brackets are the arguments as a tuple.



