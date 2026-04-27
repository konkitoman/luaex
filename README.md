# Running Lua inside Lua

If you ever wanted to run Lua inside Lua, this is a good way to run an subset of Lua.
`goto`s and labels are not implemented, and I don't see a way to be implemented without overhead!

Currently the `executor.lua`, `frontend-lua.lua` and `test_lua.lua` they are able to run inside the `executor` and compiled with `frontend-lua`,
 `final_test.lua` runs the tests inside the inside the `executor`, in the sens that `executor.lua`, `frontend-lua.lua` and `test_lua.lua` are compiled by `frontend-lua`,
 and ran by `executor`, so an virtual `executor` will run inside the `executor`, that will run the tests.

## How to use

You currently need an frontend like `frontend-lua` that is responsible to compile the code to "bytecode" that the `executor` can run.
You first call `frontend.parse(source)` with your code source, that will result in the Tokens.
And depending on what your source represent, you will use `frontend.ast_parse_expr` or `frotned.ast_parse_module` to create the AST Node.
That AST Node the will be passed to the `frontend.compile`, if you used `ast_parse_expr` is recommended to use `frontend.compile_to_function`,
 and that will result in the bytecode, that will be passed to the `executor.execute(context, bytecode)`.
The `context` it will be an table, that is used as the global scope, if you run this inside lua, you can pass `_G` to give access to everything.

Example:
```lua
local source = "return { something = true }"
local fn_module = executor.execute(context, frontend.compile(frontend.ast_parse_module(frontend.parse(source))))
-- fn_module() == { something = true }
```
At any step errors can occur, so you should call `parse`, `ast_parse_mode`, `compile` and `execute` using `pcall`, to handle errors.

## Motivation

I was working an Roblox game/"experience" from a friend.
And I needed to run Lua code on the client side, for experimenting with stuff.
Also because you cannot change the `shared` table from inside the "Command Bar".
Roblox only lets you to load lua on the server side, with the `loadstring` and only when `ServerScriptService.LoadStringEnabled` is true.
But they removed the `setfenv` and `getfenv`, so good luck virtualizing that.
And I want to run code in the client, not on the server!

I also wanted to see if is possible to run "bytecode" with the least overhead,
 and I wanted my virtual functions to be a normal function to any other lua code.

Also as an challenge to see if I'm able to implement an VM and parser for Lua in Lua.

# Story

I started this project 8 months ago, when writing this.
I written the `executor` as a proof of concept.

Then after 7 months I rewritten the `executor` and made the `frontend-lua`

# Use of AI inside this project

The initial tests were written by **Gemini 3 Fast**, but modified after.

Also **Gemini 3 Fast** was used to find what is called when a function is created and runed at the sametime,
and with that I found that is called: **Immediately Invoked Function Expression (IIFE)**.
