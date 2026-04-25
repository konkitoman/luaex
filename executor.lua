-- Lua: 5.5

local function create_stack(parent)
	local stack = {}
	local stack_state = {
		stack = stack,
		data = {},
		has = {},
		["$"] = {},
		tmp = {},
		add = function(self, name) self.has[name] = true end,
		set_return = function(_) assert("This is not a function"); end,
		set_errored = function() assert("This is not a function"); end,
		set_break = function() assert("This is not a loop"); end,
		evaluate = function() return true end,
		returns = function() assert("This is not inside a function context") end,
		errored = function() assert("This is not inside a function context") end,
		is_break = function()
			assert("This is not inside a loop context")
			return false
		end,
	}
	setmetatable(stack, {
		__index = function(_, at) if stack_state.has[at] then return stack_state.data[at] else return parent[at] end end,
		__newindex = function(_, at, value) if stack_state.has[at] then stack_state.data[at] = value else parent[at] = value end end,
	})
	return stack_state
end

local function stack_push_fn(parent_stack)
	local stack = {}
	local fn_state = {}
	local stack_state = {
		stack = stack,
		data = {},
		has = {},
		["$"] = {},
		tmp = {},
		add = function(self, name) self.has[name] = true end,
		set_return = function(t) fn_state.returns = t end,
		set_errored = function(err) fn_state.errored = err end,
		set_break = function() assert("This is not a loop"); end,
		evaluate = function(self) return self:returns() == nil end,
		returns = function() return fn_state.returns end,
		errored = function() return fn_state.errored end,
		is_break = function()
			assert("This is not inside a loop context")
			return false
		end,
	}
	setmetatable(stack, {
		__index = function(_, at) if stack_state.has[at] then return stack_state.data[at] else return parent_stack.stack[at] end end,
		__newindex = function(_, at, value) if stack_state.has[at] then stack_state.data[at] = value else parent_stack.stack[at] =
				value end end,
	})
	return stack_state
end

local function stack_push_do(parent_stack)
	local stack = {}
	local stack_state = {
		stack = stack,
		data = {},
		has = {},
		["$"] = {},
		tmp = {},
		add = function(self, name) self.has[name] = true end,
		set_return = parent_stack.set_return,
		set_errored = parent_stack.set_errored,
		set_break = parent_stack.set_break,
		evaluate = function(_) return parent_stack:evaluate() end,
		returns = parent_stack.returns,
		errored = parent_stack.errored,
		is_break = parent_stack.is_break,
	}
	setmetatable(stack, {
		__index = function(_, at) if stack_state.has[at] then return stack_state.data[at] else return parent_stack.stack[at] end end,
		__newindex = function(_, at, value) if stack_state.has[at] then stack_state.data[at] = value else parent_stack.stack[at] =
				value end end,
	})
	return stack_state
end

local function stack_push_loop(parent_stack)
	local stack = {}

	local loop_state = {}

	local stack_state = {
		stack = stack,
		data = {},
		has = {},
		["$"] = {},
		tmp = {},
		add = function(self, name) self.has[name] = true end,
		set_return = parent_stack.set_return,
		set_errored = parent_stack.set_errored,
		set_break = function() loop_state.breaks = true end,
		evaluate = function(self) return (not self:is_break()) and parent_stack:evaluate() end,
		returns = parent_stack.returns,
		errored = parent_stack.errored,
		is_break = function() return loop_state.breaks end,
	}
	setmetatable(stack, {
		__index = function(_, at) if stack_state.has[at] then return stack_state.data[at] else return parent_stack.stack[at] end end,
		__newindex = function(_, at, value) if stack_state.has[at] then stack_state.data[at] = value else parent_stack.stack[at] =
				value end end,
	})
	return stack_state
end

local function eval_expr(SS, entry)
	if not SS:evaluate() then return end

	local O = {}
	local VT = {
		function() -- 1 Define
			for i=1,#entry[2],1 do
				SS:add(entry[2][i])
			end
		end,
		function() -- 2 Set
			local _O = {}
			for I = 1, #entry[3], 1 do
				local o = eval_expr(SS, entry[3][I])
				for i = 1, #o, 1 do
					table.insert(_O, o[i])
				end
			end
			for I = 1, #entry[2], 1 do
				local P = entry[2][I]
				local l = SS.stack

				if P[2] then
					if P[2] == 0 then
						l = SS.tmp
					elseif type(P[2]) == "table" then
						l = eval_expr(SS, P[2])[1]
					end
				end

				for p=1, #P[1], 1 do
					local k
					if type(P[1][p]) == "table" then
						k = eval_expr(SS, P[1][p])[1]
					else
						k = P[1][p]
					end

					if p == #P[1] then
						l[k] = table.remove(_O, 1)
					else
						l = l[k]
					end
				end
			end
		end,
		function() -- 3 Table
			local T = {}
			for i=1,#entry[2],1 do
				T[eval_expr(SS, entry[2][i])[1]] = eval_expr(SS, entry[3][i])[1]
			end
			table.insert(O, T)
		end,
		function() -- 4 Read
			for I=1, #entry[2], 1 do
				local P = entry[2][I]

				local l = SS.stack
				if P[2] then
					if P[2] == 0 then
						l = SS.tmp
					elseif type(P[2]) == "table" then
						l = eval_expr(SS, P[2])[1]
					end
				end

				for p=1,#P[1],1 do
					local k
					if type(P[1][p]) == "table" then
						k = eval_expr(SS, P[1][p])[1]
					else
						k = P[1][p]
					end
					l = l[k]
				end

				if l ~= SS.stack and l ~= SS.tmp then
					table.insert(O, l)
				end
			end
		end,
		function() -- 5 Variadic
			for i = 1, #SS["$"], 1 do
				table.insert(O, SS["$"][i])
			end
		end,
		function() -- 6 Function
			table.insert(O, function(...)
				local FS = stack_push_fn(SS)
				local A = table.pack(...)
				for i = 1, #entry[2], 1 do
					FS:add(entry[2][i])
					FS.stack[entry[2][i]] = table.remove(A, 1)
				end
				FS["$"] = A

				local r = {}

				for I = 1, #entry[3], 1 do
					local o = eval_expr(FS, entry[3][I])
					if not FS:evaluate() then break end
					for i = 1, #o, 1 do
						table.insert(r, o[i])
					end
				end

				if FS.errored() then
					error(FS.errored())
				end

				if FS:returns() then
					return table.unpack(FS:returns())
				else
					if r then return table.unpack(r) end
				end
			end)
		end,
		function() -- 7 Insert
			table.insert(O, entry[2])
		end,
		function() -- 8 Call
			local A = {}
			for i = 1, #entry[3], 1 do
				local o = eval_expr(SS, entry[3][i])
				for i = 1, #o, 1 do
					table.insert(A, o[i])
				end
			end

			local f = eval_expr(SS, entry[2])[1]
			if not f then
				local path = ''
				if entry[2][1] == 4 then
					if entry[2][2][1] then
						if entry[2][2][1][2] then
								path = '(<expr>)'
						end
						for _, s in ipairs(entry[2][2][1][1]) do
								if type(s) == 'table' then
								if s[1] == 7 then
									if type(s[2]) == 'string' then
									path = path .. '["' .. s[2] .. '"]'
									else
										path = path .. '[' .. s[2] .. ']'
									end
								else
									path = path .. '[' .. '<expr>' .. ']'
								end
							else
								path = path .. '[' .. s .. ']'
							end
						end
					end
				end
				SS.set_errored("attempt to call nil value " .. path)
				return
			end
			local res = table.pack(pcall(f, table.unpack(A)))
			if not table.remove(res, 1) then
				SS.set_errored(res[1])
			else
				for i = 1, #res, 1 do
					table.insert(O, res[i])
				end
			end
		end,
		function() -- 9 If
			local T = eval_expr(SS, entry[2])[1]
			if T then
				local o = eval_expr(SS, entry[3])
				if not o then return end
				for i = 1, #o, 1 do
					table.insert(O, o[i])
				end
			else
				local o = eval_expr(SS, entry[4])
				if not o then return end
				for i = 1, #o, 1 do
					table.insert(O, o[i])
				end
			end
		end,
		function() -- 10 While
			while eval_expr(SS, entry[2])[1] do
				local WS = stack_push_loop(SS)
				for i = 1, #entry[3], 1 do
					eval_expr(WS, entry[3][i])
					if not WS:evaluate() then break end
				end

				if WS:is_break() or WS:errored() or WS:returns() then break end
			end
		end,
		function() -- 11 For
			local s = eval_expr(SS, entry[2])[1]
			local e = eval_expr(SS, entry[3])[1]
			local a = eval_expr(SS, entry[4])[1]
			for I = s, e, a do
				local FS = stack_push_loop(SS)
				FS:add(entry[5])
				FS.stack[entry[5]] = I

				for i = 1, #entry[6], 1 do
					eval_expr(FS, entry[6][i])
					if not FS:evaluate() then break end
				end

				if FS:is_break() or FS:errored() or FS:returns() then break end
			end
		end,
		function() -- 12 Foreach
			for a1, a2, a3 in table.unpack(eval_expr(SS, entry[2])) do
				local FS = stack_push_loop(SS)
				local r = { a1, a2, a3 }
				if #entry[3] > 3 then
					print("Too many argoments inside foreach")
				end
				for i = 1, #entry[3], 1 do
					FS:add(entry[3][i])
					FS.stack[entry[3][i]] = r[i]
				end

				for i = 1, #entry[4], 1 do
					eval_expr(FS, entry[4][i])
					if not FS:evaluate() then break end
				end

				if FS:is_break() or FS:errored() or FS:returns() then break end
			end
		end,
		function() -- 13 Until
			repeat
				local LS = stack_push_loop(SS)
				for i = 1, #entry[3], 1 do
					eval_expr(LS, entry[3][i])
					if not LS:evaluate() then break end
				end
				if LS:is_break() or LS:errored() or LS:returns() then break end
				local cond = eval_expr(LS, entry[2])
				if LS:errored() then break end
			until cond[1]
		end,
		function() -- 14 Do
			local IS = stack_push_do(SS)
			for i = 1, #entry[2], 1 do
				eval_expr(IS, entry[2][i])
				if not IS:evaluate() then break end
			end
		end,
		function() -- 15 Return
			local A = {}

			for I = 1, #entry[2], 1 do
				local o = eval_expr(SS, entry[2][I])
				for i = 1, #o, 1 do
					table.insert(A, o[i])
				end
			end

			SS.set_return(A)
		end,
		function() -- 16 Break
			SS.set_break()
		end,
		function() -- 17 Not
			table.insert(O, not eval_expr(SS, entry[2])[1])
		end,
		function() -- 18 Add
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l + r)
		end,
		function() -- 19 Sub
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l - r)
		end,
		function() -- 20 Mul
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l * r)
		end,
		function() -- 21 Div
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l / r)
		end,
		function() -- 22 Pow
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l ^ r)
		end,
		function() -- 23 Concat
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l .. r)
		end,
		function() -- 24 Or
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l | r) -- not avalibile in luau
		end,
		function() -- 25 And
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l & r) -- not avalibile in luau
		end,
		function() -- 26 Xor
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]

			table.insert(O, l ~ r) -- not avalibile in luau
		end,
		function() -- 27 Mod
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l % r)
		end,
		function() -- 28 Negative
			table.insert(O, -eval_expr(SS, entry[2])[1])
		end,
		function() -- 29 Negate
			table.insert(O, ~eval_expr(SS, entry[2])[1]) -- not avalibile in luau
		end,
		function() -- 30 Length
			table.insert(O, #eval_expr(SS, entry[2])[1])
		end,
		function() -- 31 Shl
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l << r) -- not avalibile in luau
		end,
		function() -- 32 Shr
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l >> r) -- not avalibile in luau
		end,
		function() -- 33 Less
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l > r)
		end,
		function() -- 34 EqLess
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l >= r)
		end,
		function() -- 35 Equals
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l == r)
		end,
		function() -- 36 EqGrater
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l <= r)
		end,
		function() -- 37 Grater
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l < r)
		end,
		function() -- 38 NotEquals
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l ~= r)
		end,
		function() -- 39 BoolOr
			local l = eval_expr(SS, entry[2])[1]
			if l then
				table.insert(O, true)
			else
				local r = eval_expr(SS, entry[3])[1]
				table.insert(O, l or r)
			end
		end,
		function() -- 40 BoolAnd
			local l = eval_expr(SS, entry[2])[1]
			if not l then
				table.insert(O, false)
			else
				local r = eval_expr(SS, entry[3])[1]
				table.insert(O, l and r)
			end
		end,
		function() -- 41 FloorDiv
			local l = eval_expr(SS, entry[2])[1]
			local r = eval_expr(SS, entry[3])[1]
			table.insert(O, l // r)
		end,
	}

	local c = VT[entry[1]]
	if c then c() else print("Invalid: ", entry[1]) end

	return O
end

local function execute(context, expr)
	local stack = create_stack(context)
	return table.unpack(eval_expr(stack, expr))
end

return {
	execute = execute,
}
