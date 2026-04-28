```luau
type Span = {
  start: number,
  end: number,
}
type TokenWhitespace = {
  T: "w",
  t: ' ' | '\t' | '\n',
  a: number, -- amount
}
type TokenIdent = {
  T: 'i',
  i: string,
}
type TokenLiteral = {
  T: 'l',
  t: 'n' | 'h' | 's', -- n is number, h is hex, s is string
  i: string,
}
type TokenPunct = {
  T: 'p',
  i: string,
}
type Token = (TokenWhitespace | TokenIdent | TokenLiteral | TokenPunct) & {span: Span}

-- AST
local ast = {
  301, -- do
  {
    { 300, {"a"}, {{ 5, 2 }}}, -- local
    { 300, {"b"}, { 20, { 200, {{ 6, "a" }}}, { 5, 1 } }}, -- local
    { 10, { 200, {{6, "print"}}}, {{ 200, {{ 6, "g"}}}, { 200, {{ 6, "b" }}}}}, -- call
  },
}
-- BIN
local bin = {
  14
  {
    { 2, {{1}},{7,2}},
    { 2, {{"a"}},{4,{{1}}}},
    { 2, {{1}},{ 18,{4,{{"a"}}},{7,1}}},
    { 2, {{"b"}},{4,{{1}}}},
    { 8, {"print"},{4,{{"a"},{"b"}}}},
  }
}
```

So what is valid lua, and how I can determine when an expression or statement is finished.
So from: https://www.lua.org/manual/5.1/manual.html

>[!quote] Keywords
>```
>and break do else elseif
>end false for function if
>in local nil not or
>repeat return then true until while
>```

>[!quote] Reserved Tokens
>```
>+ - * / % ^ #
>== ~= <= >= < > =
>( ) { } [ ]
>; : , . .. ...
>```

Long Bracket:
- `[[` opening with level 0
- `[=[` opening with level 1
- `]]` closing with level 0
- `]=]` closing with level 1
Can only be closed when the opening and closing has the same level.
They are used for long strings and comments.
An comment looks like: `--[[this is a multiline comment with level 0]]`

Strings:
- `'` and `"` are normal strings, that supports escape sequences.
- `[[`, `[=[` closing bracket string, are long strings, that don't interpret escape sequences.

Comments:
- `--` is a single line comment, will end at the `"\n"`
- `--[[` this is a multiline comment will end at the matching closing Long Bracket.

Calling a function:
We have the `print` function to call
All of those examples will output `21`
```lua
print(21)
print         (21)
print(10+11)
print  (   10   +   11   )
print(1+10*2)
print(1+(1+9)*2)
print(0^0+10*2) -- 21.0
print(1+2*10^1) -- 21.0
print'21'
print         '21'
print"21"
print         "21"
print[[21]]
print[=[21]=]
print--[[lol]](21)
print--[[lol]](21)
print--[[lol]]"21"
print--[[lol]][[21]]
print--[=[lol]][[not 21 this]]]=][[21]]
print(setmetatable({},{__tostring=function()return'21'end}))
```
Also you can pass an table as the first argument using:
```lua
print{}
print  {}
```
But this will result in `table: {ptr hex address}`

# Abstract Syntax Tree

| value | name        |
| ----- | ----------- |
| 0     | nil         |
| 1     | false       |
| 2     | true        |
| 3     | not         |
| 4     | function    |
| 5     | number      |
| 6     | string      |
| 7     | table       |
| 10    | call        |
| 11    | bool and    |
| 12    | bool or     |
| 20    | `+` add     |
| 21    | `-` sub     |
| 22    | `*` mul     |
| 23    | `/` div     |
| 24    | `^` pow     |
| 25    | `~` xor     |
| 26    | `&` bit and |
| 27    | `%` modulo  |
| 28    | `<` grater  |
| 29    | `>` less    |
| 30    | equals      |
| 31    | not equals  |
| 32    | concat      |
| 33    | `//`        |
| 34    | `|` bit or  |
| 35    | `<<` shl    |
| 36    | `>>` shr    |
| 38    | `<=`        |
| 39    | `>=`        |
| 50    | - subtract  |
| 51    | # get len   |
| 52    | ~ negate    |
| 100   | group       |
| 101   | variadic    |
| 200   | path        |
| 300   | local       |
| 301   | do          |
| 302   | if          |
| 303   | while       |
| 304   | for         |
| 305   | repeat      |
| 306   | d function  |
| 307   | return      |
| 308   | break       |
| 309   | foreach     |
| 310   | set         |
