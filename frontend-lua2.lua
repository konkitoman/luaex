local function show_table(table, depth)
  depth = depth or 0
  if type(table) == "table" then
    local out = "{\n"
    for i, v in pairs(table) do
      if tonumber(i) then
        out = out .. string.format("%s[%s] = %s,\n", string.rep("    ", depth + 1), i, show_table(v, depth + 1))
      else
        out = out .. string.format("%s[\"%s\"] = %s,\n", string.rep("    ", depth + 1), i, show_table(v, depth + 1))
      end
    end
    return out .. string.rep("    ", depth) .. "}"
  elseif type(table) == "string" then
    return string.format("\"%s\"", table)
  else
    return string.format("%s", table)
  end
end

local function parse_string(C, w)
  local i = C[2]
  local c = string.sub(C[1], i, i)
  if c == w then
      local S = i
      local o = ''
      i = i + 1
      while i <= #C[1] do
        c = string.sub(C[1], i, i)
        if c == '\\' then
          c = string.sub(C[1], i + 1, i + 1)
          if c then
            local t = {
              a = "\a",
              b = "\b",
              f = "\f",
              n = "\n",
              r = "\r",
              t = "\t",
              v = "\v",
              ['\\'] = '\\',
              ['\''] = '\'',
              ['\"'] = '\"',
              ['0'] = '\0',
            }
            if t[c] then
              o = o .. t[c]
              i = i + 1
            else
              error("Unknown escape sequence: \\" .. c)
            end
          else
            error("Invalid escape, is at the end of the source")
          end
        elseif c == w then
          break
        else
          o = o .. c
        end
        i = i + 1
      end
      table.insert(C[3], {T = 'l', t = w, i = o, span = {S, i}})
      C[2] = i + 1
      return true
    end
  return false
end

local function parse_long_bracket(C)
  local i = C[2]
  local s,e = string.find(C[1], "^%[=*%[", i)
  if not s or s>=e then
    return nil
  end
  local S, B = s, e+1
  local a = (e-s) - 1
  s,e = string.find(C[1], "]" .. string.rep('=', a) .. "]", e, true)
  if not s or s>=e then
    error("Unclosed long Bracket")
    return nil
  end
  return {S,e}, a, string.sub(C[1], B, s-1)
end

local function parse_long_string(C)
  local span, a, i = parse_long_bracket(C)
  if not span then return false end
  C[2]=span[2]+1
  table.insert(C[3], {T='l',t=a, i=i, span = span})
  return true
end

local function parse(source)
  local C = {source, 1, {}}
  local i = 1
  while i <= #source do
    local s,e,r
    repeat
      s, e = string.find(source, '^ *', i)
      if s and s <= e then
        table.insert(C[3], {T = 'w', t = ' ', amount = 1 + e - s, span = {s, e}})
        i = e + 1
        break
      end
      s, e = string.find(source, '^\t*', i)
      if s and s <= e then
        table.insert(C[3], {T = 'w', t = '\t', amount = 1 + e - s, span = {s, e}})
        i = e + 1
        break
      end
      s, e = string.find(source, '^\n*', i)
      if s and s <= e then
        table.insert(C[3], {T = 'w', t = '\n', amount = 1 + e - s, span = {s, e}})
        i = e + 1
        break
      end
      s,e,r = string.find(source, '^(%d+%.?%d*)', i)
      if s and s <= e then
        table.insert(C[3], {T = 'l', t = 'n', i=r, span = {s, e}})
        i = e + 1
        break
      end
      s,e,r = string.find(source, '^(0x%d+%.?%d*)', i)
      if s and s <= e then
        table.insert(C[3], {T = 'l', t = 'n', i=r, span = {s, e}})
        i = e + 1
        break
      end
      s,e,r = string.find(source, '^(%a%w*)', i)
      if s and s <= e then
        table.insert(C[3], {T = 'i', i=r, span = {s, e}})
        i = e + 1
        break
      end
      C[2] = i
      if parse_string(C, '\'') or parse_string(C, '\"') or parse_long_string(C) then i = C[2] break end
      s,e = string.find(source, "^%-%-", i)
      if s and s<e then
        i = i + 2
        C[2] = i
        local span, a, c = parse_long_bracket(C)
        if span then
          i = span[2]+1
          table.insert(C[3], {T='c', a=a, i=c, span={span[1]-2,span[2]}})
          break
        end
        local S = s
        s = string.find(source, '\n', i, true)
        E = s or #source
        i = E + 1
        table.insert(C[3], {T='c', i=string.sub(source, S+2, E-1), span = {S,E}})
        break
      end
      s,e,r = string.find(source, '^(%p)', i)
      if s and s <= e then
        table.insert(C[3], {T = 'p', i=r, span = {s, e}})
        i = e + 1
        break
      end
    until true
  end

  return C[3]
end

local source = "local a = 2;local b = a + 1;print(a, b)"
local tokens = {
  { ["i"] = "local", ["T"] = "i", },
  { ["amount"] = 1, ["T"] = "w", ["t"] = " ", },
  { ["i"] = "a", ["T"] = "i", },
  { ["amount"] = 1, ["T"] = "w", ["t"] = " ", },
  { ["i"] = "=", ["T"] = "p", },
  { ["amount"] = 1, ["T"] = "w", ["t"] = " ", },
  { ["i"] = "2", ["T"] = "l", ["t"] = "n", },
  { ["i"] = ";", ["T"] = "p", },
  { ["i"] = "local", ["T"] = "i", },
  { ["amount"] = 1, ["T"] = "w", ["t"] = " ", },
  { ["i"] = "b", ["T"] = "i", },
  { ["amount"] = 1, ["T"] = "w", ["t"] = " ", },
  { ["i"] = "=", ["T"] = "p", },
  { ["amount"] = 1, ["T"] = "w", ["t"] = " ", },
  { ["i"] = "a", ["T"] = "i", },
  { ["amount"] = 1, ["T"] = "w", ["t"] = " ", },
  { ["i"] = "+", ["T"] = "p", },
  { ["amount"] = 1, ["T"] = "w", ["t"] = " ", },
  { ["i"] = "1", ["T"] = "l", ["t"] = "n", },
  { ["i"] = ";", ["T"] = "p", },
  { ["i"] = "print", ["T"] = "i", },
  { ["i"] = "(", ["T"] = "p", },
  { ["i"] = "a", ["T"] = "i", },
  { ["i"] = ",", ["T"] = "p", },
  { ["amount"] = 1, ["T"] = "w", ["t"] = " ", },
  { ["i"] = "b", ["T"] = "i", },
  { ["i"] = ")", ["T"] = "p", },
}

local function tok_trim(C)
  local i = C[2]
  while i <= #C[1] do
    local t = C[1][i]
    if t.T ~= "w" and t.T ~= "c" then
      break
    end
    i = i + 1
  end
  C[2] = i
end

local keywords = {
  ["and"] = true,
  ["break"] = true,
  ["do"] = true,
  ["else"] = true,
  ["elseif"] = true,
  ["end"] = true,
  ["false"] = true,
  ["for"] = true,
  ["function"] = true,
  ["if"] = true,
  ["in"] = true,
  ["local"] = true,
  ["nil"] = true,
  ["not"] = true,
  ["or"] = true,
  ["repeat"] = true,
  ["return"] = true,
  ["then"] = true,
  ["true"] = true,
  ["until"] = true,
  ["while"] = true,
}
local ast_parse_stmt
local ast_parse_path
local ast_parse_expr
local ast_parse_call
local ast_parse_table
local function ast_parse_expr_(C)
  local t = C[1][C[2]]
  if not t then return end
  if t.T == 'i' then
    if t.i == "nil" then
      C[2] = C[2] + 1
      return {0, span = t.span}
    elseif t.i == "false" then
      C[2] = C[2] + 1
      return {1, span = t.span}
    elseif t.i == "true" then
      C[2] = C[2] + 1
      return {2, span = t.span}
    elseif t.i == "not" then
      C[2] = C[2] + 1
      tok_trim(C)
      local e = ast_parse_expr(C)
      if not e then
        error("Incomplete `not` expression at: " .. t.span[1] .. "-" .. t.span[2])
      end
      C[2] = C[2] + 1
      return {3, e, span = {t.span[1], e.span[2]}}
    elseif t.i == "function" then
      -- 4
      error("to do function")
    elseif keywords[t.i]     then
       return
    else
      local p = ast_parse_path(C)
      local c = ast_parse_call(C, p)
      if c then
        return c
      end
      return p
    end
  elseif t.T == 'l' then
    if t.t == 'n' then
      C[2] = C[2] + 1
      return {5, tonumber(t.i), span = t.span}
    elseif t.t == "\'" or t.t == "\"" or type(t.t) == "number" then
      C[2] = C[2] + 1
      return {6, t.i, span = t.span}
    else
      error("Unknown literal at: " .. t.span[1] .. "-" .. t.span[2])
    end
  elseif t.T == 'p' then
    if t.i == ")" then
      return
    elseif t.i == "{" then
      return ast_parse_table(C)
    end

    C[2] = C[2] + 1
    local s = C[1][C[2]]
    if s and s.T == 'p' then
      if t.i == "." and s.i == "." then
        C[2] = C[2] + 1
        local l = C[1][C[2]]
        if l.T == 'p' and l.i == "." then
          C[2] = C[2] + 1
          return {101, span={t.span[1],l.span[2]}}
        else
          error(".. ?")
        end
      else
        error(". ?")
      end
    end
    tok_trim(C)
    local r = ast_parse_expr(C)
    if t.i == "-" then
      if not r then
        error("Invalid `-` no right: " .. t.span[1] .. "-")
      end
      C[2] = C[2] + 1
      return {50, r}
    elseif t.i == "#" then
      if not r then
        error("Invalid `#` no right: " .. t.span[1] .. "-")
      end
      C[2] = C[2] + 1
      return {51, r}
    elseif t.i == "~" then
      if not r then
        error("Invalid `~` no right: " .. t.span[1] .. "-")
      end
      C[2] = C[2] + 1
      return {52, r}
    elseif t.i == "(" then
      if not r then
        error("Invalid `~` no right: " .. t.span[1] .. "-")
      end
      C[2] = C[2] + 1
      return {100, r, span = {t.span[1], r.span[2]}}
    end
  end
end

ast_parse_expr = function(C)
  tok_trim(C)
  local l = ast_parse_expr_(C)
  if not l then
    return
  end
  local S = C[2]
  tok_trim(C)
  local t = C[1][C[2]]
  if not t then return l end
  if t.T == "i" then
    if t.i == "and" then
      C[2] = C[2] + 1
      tok_trim(C)
      local r = ast_parse_expr(C)
      if not r then
        error("Invalid `and` expresion no, right at: " .. t.span[1] .. "-")
      end
      return {11, l, r, span={l.span[1], r.span[2]}}
    elseif t.i == "or" then
      C[2] = C[2] + 1
      tok_trim(C)
      local r = ast_parse_expr(C)
      if not r then
        error("Invalid `or` expresion no, right at: " .. t.span[1] .. "-")
      end
      return {12, l, r, span={l.span[1], r.span[2]}}
    else
      C[2] = S
      return l
    end
  elseif t.T == "p" then
    C[2] = C[2] + 1
    local s = C[1][C[2]]

    if s and s.T == "p" then
      C[2] = C[2] + 1
      tok_trim(C)
      local r = ast_parse_expr(C)
      if t.i == "=" and s.i == "=" then
        if not r then
          error("Invalid `==` operation no, right at: " .. t.span[1] .. "-")
        end
        return {30, l, r, span={l.span[1], r.span[2]}}
      elseif t.i == "~" and s.i == "=" then
        if not r then
          error("Invalid `~=` operation no, right at: " .. t.span[1] .. "-")
        end
        return {31, l, r, span={l.span[1], r.span[2]}}
      elseif t.i == "<" and s.i == "=" then
        if not r then
          error("Invalid `<=` operation no, right at: " .. t.span[1] .. "-")
        end
        return {38, l, r, span={l.span[1], r.span[2]}}
      elseif t.i == "." and s.i == "." then
        if not r then
          error("Invalid `..` operation no, right at: " .. t.span[1] .. "-")
        end
        return {32, l, r, span={l.span[1], r.span[2]}}
      elseif t.i == ">" and s.i == "=" then
        if not r then
          error("Invalid `>=` operation no, right at: " .. t.span[1] .. "-")
        end
        return {39, l, r, span={l.span[1], r.span[2]}}
      end
    end

    tok_trim(C)

    local r = ast_parse_expr(C)
    if t.i == "+" then
      if not r then
        error("Invalid `+` expresion no, right at: " .. t.span[1] .. "-")
      end
      return {20, l, r, span={l.span[1], r.span[2]}}
    elseif t.i == "-" then
      if not r then
        error("Invalid `-` expresion no, right at: " .. t.span[1] .. "-")
      end
      return {21, l, r, span={l.span[1], r.span[2]}}
    elseif t.i == "*" then
      if not r then
        error("Invalid `*` expresion no, right at: " .. t.span[1] .. "-")
      end
      return {22, l, r, span={l.span[1], r.span[2]}}
    elseif t.i == "/" then
      if not r then
        error("Invalid `/` expresion no, right at: " .. t.span[1] .. "-")
      end
      return {23, l, r, span={l.span[1], r.span[2]}}
    elseif t.i == "^" then
      if not r then
        error("Invalid `^` expresion no, right at: " .. t.span[1] .. "-")
      end
      return {24, l, r, span={l.span[1], r.span[2]}}
    elseif t.i == "~" then
      if not r then
        error("Invalid `~` expresion no, right at: " .. t.span[1] .. "-")
      end
      return {25, l, r, span={l.span[1], r.span[2]}}
    elseif t.i == "&" then
      if not r then
        error("Invalid `&` expresion no, right at: " .. t.span[1] .. "-")
      end
      return {26, l, r, span={l.span[1], r.span[2]}}
    elseif t.i == "%" then
      if not r then
        error("Invalid `%` expresion no, right at: " .. t.span[1] .. "-")
      end
      return {27, l, r, span={l.span[1], r.span[2]}}
    elseif t.i == "<" then
      if not r then
        error("Invalid `<` expresion no, right at: " .. t.span[1] .. "-")
      end
      return {28, l, r, span={l.span[1], r.span[2]}}
    elseif t.i == ">" then
      if not r then
        error("Invalid `>` expresion no, right at: " .. t.span[1] .. "-")
      end
      return {29, l, r, span={l.span[1], r.span[2]}}
    end
  end
  C[2] = S
  return l
end

local ast_parse_path_
ast_parse_path_ = function(C, S)
  tok_trim(C)
  local s = C[1][C[2]]
  if s then
    if s.T == "i" then
      if keywords[s.i] then
        return
      else
        error("ident after ident that is not a keyward at: " .. s.span[1] .. '-' .. s.span[2])
      end
    elseif s.T == "p" then
      if s.i == "." then
        C[2] = C[2] + 1
        tok_trim(C)
        local l = ast_parse_path(C)
        if not l then
          error("Cannot read path at: " .. S .. "-" .. s.span[2])
        end
        return l
      elseif s.i == "[" then
        C[2] = C[2] + 1
        local e = ast_parse_expr(C)
        if not e then
          error("Cannot read path at: " .. S .. "-" .. s.span[2])
        end
        s = C[1][C[2]]
        if not s and s.T ~= 'p' or s.i ~= ']' then
          error("Cannot path with expresion is not ending in `]` at: " .. S .. "-" .. s.span[2])
        end
        C[2] = C[2] + 1
        local r = ast_parse_path_(C, S)
        if not r then
          return {200, {e}, span = e.span}
        end
        table.insert(r[2], 1, e)
        return {200, r[2], span = {e.span[1], r.span[2]}}
      elseif s.i == ";" then
        C[2] = C[2] + 1
      end
    end
  end
end
ast_parse_path = function(C)
  local t = C[1][C[2]]
  if not t or t.T ~= "i" or keywords[t.i] then
    return
  end

  C[2] = C[2] + 1
  local r = ast_parse_path_(C, t.span[1])
  if r then
    table.insert(r[2], 1, {6, t.i, span = t.span})
    r.span[1] = t.span[1]
    return r
  end

  return {200, {6, t.i, span = t.span}, span = t.span}
end
ast_parse_table = function(C)
  local S  = C[2]
  local a = C[1][C[2]]
  if a.T ~= 'p' or a.i ~= '{' then
    return
  end
  C[2] = C[2] + 1
  tok_trim(C)
  a = C[1][C[2]]

  local k, v = {}, {}
  local i = 1

  repeat
    repeat
      if a.T == 'p' and a.i == '[' then
        C[2] = C[2] + 1
        local l = ast_parse_expr(C)
        if not l then
          error("Invalid expresion in table key")
        end
        a = C[1][C[2]]
        if not a or a.T ~= "p" or a.i ~= "]" then
          error("Invalid table key, expected ]")
        end
        C[2] = C[2] + 1
        tok_trim(C)
        a = C[1][C[2]]
        if not a or a.T ~= "p" or a.i ~= "=" then
          error("Invalid table entry, expected =")
        end
        C[2] = C[2] + 1
        local r = ast_parse_expr(C)
        if not r then
          error("Invalid value in table")
        end
        table.insert(k, l)
        table.insert(v, r)
        tok_trim(C)
        a = C[1][C[2]]
      else
        local l = ast_parse_expr(C)
        tok_trim(C)
        a = C[1][C[2]]
        if not l then
          error("Cannot get table key")
        end
        if l[1] == 200 and #l[2] == 1 then
          if a.T ~= 'p' or a.i ~= '=' then
            table.insert(k, {5, i})
            i = i + 1
            table.insert(v, l)
            break
          end
        end
        l = l[2]
        if a.T ~= 'p' or a.i ~= '=' then
          error("Expect =")
        end
        C[2] = C[2] + 1
        local r = ast_parse_expr(C)
        table.insert(k, l)
        table.insert(v, r)
        tok_trim(C)
        a = C[1][C[2]]
      end
    until true
    a = C[1][C[2]]
    if a.T ~= 'p' or (a.i ~= ',' and a.i ~= '}') then
      error("Expect , or }")
    end
    if a.T == 'p' and a.i == ',' then
      C[2] = C[2] + 1
      tok_trim(C)
      a = C[1][C[2]]
    end
  until a.T == 'p' and a.i == '}'
  C[2] = C[2] + 1

  return {7, k, v, span={S, a.span[2]}}
end

ast_parse_call = function(C, p)
  local S, E  = C[2], 0
  local a = C[1][C[2]]
  if a.T == "p" and a.i == '(' then
    local P, e = {}, nil
    repeat
      C[2] = C[2] + 1
      e = ast_parse_expr(C)
      if e then
        table.insert(P, e)
      end
      tok_trim(C)
      a = C[1][C[2]]
    until not a or (a.T == "p" and a.i == ')')
    if not a then
      error("Unclosed call")
    end
    E = a.span[2]
    C[2] = C[2] + 1
    return {10, p, P, span = {S, E}}
  elseif a.T == "p" and a.i == '{' then
    local t = ast_parse_table(C)
    if not t then
      error("Cannot parse table")
    end
    C[2] = C[2] + 1
    return {10, p, {t}, span = {S, t.span[2]}}
  elseif a.T == "l" and (a.t == '\'' or a.t == '\"' or type(a.t) == "number") then
    C[2] = C[2] + 1
    return {10, p, {{6, a.i, span = a.span}}, span = {S, E}}
  end
end

ast_parse_stmt = function(C)
  tok_trim(C)
  local t = C[1][C[2]]
  if t.T == 'i' then
    if t.i == "local" then
      local S, E = t.span[1], t.span[2]
      local D = {}
      local a
      repeat
        C[2] = C[2] + 1
        tok_trim(C)
        a = C[1][C[2]]
        if not a then
          error("local but nothing is specified after")
        end
        E = a.span[2]
        if a.T == 'i' then
          if keywords[a.i] then
            if #D == 0 then
              error("Local expects at least one name")
            else
              return {300, D, span = {S, E}}
            end
          else
            table.insert(D, a.i)
          end
        elseif a.T == 'p' then
          if a.i ~= "," and a.i ~= '=' then
            error("invalid punct in local statement: " .. a.i)
          end
        else
          error("local expects names")
        end
      until a.i == '='
      local e = {}
      repeat
        C[2] = C[2] + 1
        local l = ast_parse_expr(C)
        if not l then break end
        table.insert(e, l)
        E = l.span[2]
        tok_trim(C)
        a = C[1][C[2]]
      until not a or (a.T == "i" and keywords[a.i]) or (a.T == "p" and a.i == ';')
      return {300, D, e, span={S, E}}
    elseif t.i == "do" then
    elseif t.i == "if" then
    elseif t.i == "while" then
    elseif t.i == "for" then
    elseif t.i == "repeat" then
    elseif t.i == "function" then
    else
      local S, E = t.span[1], t.span[2]
      L = {}
      local a
      repeat
        tok_trim(C)
        local p = ast_parse_path(C)
        if p then
          table.insert(L, p)
        end
        tok_trim(C)
        a = C[1][C[2]]
        if a then
          E = a.span[2]
          local c = ast_parse_call(C, p)
          if c then
            return c
          end
        end
      until not a or (a.T == 'i' and keywords[a.i]) or (a.T == 'p' and a.i == '=')

      if a and a.T == 'p' and a.i == '=' then
        local e = {}
        repeat
          C[2] = C[2] + 1
          local l = ast_parse_expr(C)
          if not l then break end
          table.insert(e, l)
          E = l.span[2]
          tok_trim(C)
          a = C[1][C[2]]
        until not a or (a.T == "i" and keywords[a.i]) or (a.T == "p" and a.i == ';')
      end
    end
  end
end

print(show_table(ast_parse_stmt({parse([=[print{[2]=21,foo=2}]=]), 1})))


