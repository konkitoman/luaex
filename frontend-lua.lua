local function show_table(table, depth)
  depth = depth or 0
  if type(table) == "table" then
    local out = "{\n"
    for i, v in pairs(table) do
      out = out .. string.format("%s%s = %s\n", string.rep("\t", depth + 1), i, show_table(v, depth + 1))
    end
    return out .. string.rep("\t", depth) .. "}"
  elseif type(table) == "string" then
    return string.format("\"%s\"", table)
  else
    return string.format("%s", table)
  end
end

local function find_first(s, p)
  local I, U = nil, nil
  for _, p in pairs(p) do
    local i, u = string.find(s, p)
    if i and (I == nil or i < I) then
      I, U = i, u
    end
  end

  local match = nil
  if I and U then match = string.sub(s, I, U) end

  return I, U, match
end

local function trim_whitespace(s)
  for i = 1, #s, 1 do
    local b = string.byte(s, i)
    if not (b == 32 or b == 9) then return string.sub(s, i) end
  end
  return ""
end

local function match(s, p)
  for k, c in pairs(p) do
    local a, u = string.find(s, k, 1, true)
    if a == 1 then
      return c(u)
    end
  end
end

local parse_expr
local parse

local function parse_string(source)
  local out = ""
  local e = 0
  local escape = false

  if string.sub(source, 1, 1) ~= "\"" then return out, s end
  local s = string.sub(source, 2)

  while #s > 0 do
    local ch = string.sub(s, 1, 1)

    if escape then
      if ch == "\\" then
        out = out .. "\\"
      elseif ch == "n" then
        out = out .. "\n"
      else
        assert(false, "Unknown excape" .. ch)
      end
      escape = false
    else
      escape = false
      if ch == "\\" then
        escape = true
      elseif ch == "\"" then
        s = string.sub(s, 2)
        break
      else
        out = out .. ch
      end
    end

    s = string.sub(s, 2)
    e = e + 1
  end

  return out, s
end

local function parse_number(source)
  local s = source
  local e = 0

  while #s > 0 do
    local res = string.byte(s, 1) - 48
    if not res or res < 0 or res > 9 then break end
    s = string.sub(s, 2)
    e = e + 1
  end

  return { T = "N", tonumber(string.sub(source, 1, e)) }, s
end

local function parse_path(source)
  local path = {}
  local s = source
  local i, c

  while s and s ~= 0 do
    i, _, c = find_first(s, {" ", "%.", "%[", "%(", "=", ";", "\n", ","})
    if i then
      local p = string.sub(s, 1, i - 1)
      if #p > 0 then
        table.insert(path, p)
      end
    else
      table.insert(path, string.sub(s, 1))
      return path, ""
    end
    i, _, c = find_first(s, {"%.", "%[", "%(", "=", ";", "\n", ","})
    s = string.sub(s, i)

    if c == "\n" or c == "," or c == "(" or c == "=" or c == ";" then
      return path, s
    end

    if c == "[" then
      local v
      s = string.sub(s, 2)
      v, s = parse_expr(s)
      table.insert(path, v)
      assert(string.sub(s, 1, 1) == "]", "Incolplete path")
      s = trim_whitespace(string.sub(s, 2))
    end

    if c == "." then
      s = trim_whitespace(string.sub(s, 2))
    end
  end
end

local function parse_anon_function(source)
  local out = {T = "F", A = {}}

  if string.sub(source, 1, 1) ~= "(" then assert(false, "This is not an annon function") end
  local s = trim_whitespace(string.sub(source, 2))
  while #s ~= 0 do
    local i,_,c = find_first(s, {",", " ", ")"})
    if not i then assert(false) end
    if i ~= 1 then table.insert(out.A, string.sub(s, 1, i-1)) end
    i,_,c = find_first(s, {",", ")"})
    if not i then assert(false) end
    s = trim_whitespace(string.sub(s, i+1))
    if c == ")" then break end
  end

  while s and #s ~= 0 do
    if match(s, {
      ["end"] = function(e)
        s = string.sub(s, e + 1)
        return true
      end
    }) then break end
    local e

    e, s = parse(s)
    if e then table.insert(out, e) end
    s = trim_whitespace(s)
  end

  return out, s

end

function parse_expr(source)
  if string.match(source, "^[0-9]") then
    return parse_number(source)
  end

  if string.sub(source, 1, 1) == "\"" then
    return parse_string(source)
  end

  return match(source, {
    ["function"] = function(n)
      return parse_anon_function(trim_whitespace(string.sub(source, n + 1)))
    end,
    ["{"] = function(m)
    end,
  })
end

function parse(source)
  local res = table.pack(match(source, {
    ["local"] = function(u)
      local idents = {}
      local s = trim_whitespace(string.sub(source, u + 1))
      local i, e, w = nil, nil, nil
      while true do
        i, e, w = find_first(s, { "=", " ", ",", "\n", ";" })
        if not i then
          table.insert(idents, s)
          return {T = "L", I = idents}, ""
        end
        table.insert(idents, string.sub(s, 1, i - 1))
        i, e, w = find_first(s, { "=", ",", "\n", ";" })
        if w == "\n" or w == ";" then
          return {T = "L", I = idents}, string.sub(s, i + 1)
        end
        if w == "=" then break end
        if w == "," then
          s = trim_whitespace(string.sub(s, e + 1))
        end
      end

      if w ~= "=" then
        assert(false, "after local expects =")
      end

      s = trim_whitespace(string.sub(s, e + 1))
      local values = {}

      local v = nil
      while true do
        v, s = parse_expr(s)
        table.insert(values, v)
        s = trim_whitespace(s)
        if #s == 0 or string.sub(s, 1, 1) ~= "," then
          break
        end
        s = trim_whitespace(string.sub(s, 2))
      end

      return { T = "L", I = idents, V = values }, s
    end,
    ["function"] = function(u)
      local path, s = parse_path(trim_whitespace(string.sub(source, u + 1)))
      assert(string.sub(s, 1, 1) == "(")
      local f, res = parse_anon_function(s)
      return {T = "G", I = path, V = f}, res
    end,
    ["while"] = function()
    end,
    ["for"] = function()
    end,
    [";"] = function()
      return nil, trim_whitespace(string.sub(source, 2))
    end,
    ["\n"] = function()
      return nil, trim_whitespace(string.sub(source, 2))
    end
  }))

  if #res ~= 0 then
    return table.unpack(res)
  end

  local paths = {}
  local s = source
  local e, w = nil, nil
  while true do
    if #s == 0 then return nil, "" end
    local p
    p, s = parse_path(s)
    s = trim_whitespace(s)
    if p then
      table.insert(paths, p)
    end
    w = string.sub(s, 1, 1)
    if w == "=" then
      e = 1
      break
    end
    if w == "," then
      s = trim_whitespace(string.sub(s, 2))
    end
  end

  if w == "(" then

  end
  
  if w ~= "=" then
    assert(false, "after local expects =")
  end
  s = trim_whitespace(string.sub(s, e + 1))
  local values = {}

  local v = nil
  while true do
    if #s == 0 then return nil, "" end
    v, s = parse_expr(s)
    table.insert(values, v)
    s = trim_whitespace(s)
    if #s == 0 or string.sub(s, 1, 1) ~= "," then
      break
    end
    s = trim_whitespace(string.sub(s, 2))
  end

  return { T = "S", I = paths, V = values }, s
end


local t, r = parse("local a = 3")

print(show_table(t), r)
