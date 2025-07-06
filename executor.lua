local function create_stack(parent)
	local stack = {}
	local stack_state = {
		stack = stack,
		data = {},
		has = {},
		["$"] = {},
		tmp = {},
		add = function(self, name) self.has[name] = true end,
		set_return = function(_, _) assert("This is not a function"); end,
		set_errored = function(_) assert("This is not a function"); end,
		set_break = function(_) assert("This is not a loop"); end,
		set_continue = function(_) assert("This is not a loop"); end,
		evaluate = function(_) return true end,
		returns = function(_) assert("This is not inside a function context") end,
		errored = function(_) assert("This is not inside a function context") end,
		is_break = function(_)
			assert("This is not inside a loop context")
			return false
		end,
		is_continue = function(_)
			assert("This is not inside a loop context")
			return false
		end
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
		set_return = function(_, t) fn_state.returns = t end,
		set_errored = function(_) fn_state.errored = true end,
		set_break = function(_) assert("This is not a loop"); end,
		set_continue = function(_) assert("This is not a loop"); end,
		evaluate = function(self) return self:returns() == nil end,
		returns = function(_) return fn_state.returns end,
		errored = function(_) return fn_state.errored end,
		is_break = function(_)
			assert("This is not inside a loop context")
			return false
		end,
		is_continue = function(_)
			assert("This is not inside a loop context")
			return false
		end
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
		set_continue = parent_stack.set_continue,
		evaluate = function(_) return parent_stack:evaluate() end,
		returns = function(_) assert("This is not inside a function context") end,
		errored = function(_) assert("This is not inside a function context") end,
		is_break = function(_)
			assert("This is not inside a loop context")
			return false
		end,
		is_continue = function(_)
			assert("This is not inside a loop context")
			return false
		end
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
		set_break = function(_) loop_state.breaks = true end,
		set_continue = function(_) loop_state.continues = true end,
		evaluate = function(self) return (not (self:is_continue() or self:is_break())) and parent_stack:evaluate() end,
		returns = function(_) assert("This is not inside a function context") end,
		errored = function(_) assert("This is not inside a function context") end,
		is_break = function(_) return loop_state.breaks end,
		is_continue = function(_) return loop_state.continues end
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
		["D"] = function()
			for i=1,#entry,1 do
				SS:add(entry[i])
			end
		end,
		["="] = function()
			local _O = {}
			for I = 1, #entry, 1 do
				local o = eval_expr(SS, entry[I])
				for i = 1, #o, 1 do
					table.insert(_O, o[i])
				end
			end
			for I = 1, #entry.P, 1 do
				local P = entry.P[I]
				if tonumber(P) then
					if entry.L and entry.L[I] then
						SS.tmp[P][eval_expr(SS, entry.L[I])[1]] = table.remove(_O, 1)
					else
						SS.tmp[P] = table.remove(_O, 1)
					end
				else
					local l = SS.stack
					for i, at in pairs(P) do
						if i == #P then break end
						l = l[at]
					end
					if entry.L and entry.L[I] then
						l[P[#P]][eval_expr(SS, entry.L[I])[1]] = table.remove(_O, 1)
					else
						l[P[#P]] = table.remove(_O, 1)
					end
				end
			end
			for i = 1, #_O, 1 do
				table.insert(O, _O[i])
			end
		end,
		["I"] = function()
			table.insert(O, entry[1])
		end,
		["!"] = function()
			table.insert(O, not eval_expr(SS, entry[1])[1])
		end,
		["T"] = function()
			local T = {}
			for i=1,#entry,1 do
				T[eval_expr(SS, entry[i][1])[1]] = eval_expr(SS, entry[i][2])[1]
			end
			table.insert(O, T)
		end,
		["@"] = function()
			for I=1, #entry, 1 do
				if tonumber(entry[I]) then
					if entry.L and entry.L[I] then
						table.insert(O, SS.tmp[entry[I]][eval_expr(SS, entry.L[I])[1]])
					else
						table.insert(O, SS.tmp[entry[I]])
					end
				else
					local l = SS.stack
					for _, at in pairs(entry[I]) do
						l = l[at]
					end
					if entry.L and entry.L[I] then
						table.insert(O, l[eval_expr(SS, entry.L[I])[1]])
					else
						table.insert(O, l)
					end
				end
			end
		end,
		["F"] = function()
			local fn = {}
			setmetatable(fn, {
				__call = function(_, ...)
					local FS = stack_push_fn(SS)
					local A = table.pack(...)
					for i = 1, #entry.A, 1 do
						FS:add(entry.A[i])
						FS.stack[entry.A[i]] = table.remove(A, 1)
					end
					FS["$"] = A

					local r = {}

					for I = 1, #entry, 1 do
						local o = eval_expr(FS, entry[I])
						if not FS:evaluate() then break end
						for i = 1, #o, 1 do
							table.insert(r, o[i])
						end
					end

					if FS.errored() then
						assert(false)
					end

					if FS:returns() then
						return table.unpack(FS:returns())
					else
						if r then return table.unpack(r) end
					end
				end,
			})
			table.insert(O, fn)
		end,
		["$"] = function()
			for i = 1, #SS["$"], 1 do
				table.insert(O, SS["$"][i])
			end
		end,
		["C"] = function()
			local A = {}
			for i = 1, #entry, 1 do
				local o = eval_expr(SS, entry[i])
				for i = 1, #o, 1 do
					table.insert(A, o[i])
				end
			end

			local l = SS.stack
			for _, at in pairs(entry.P) do
				l = l[at]
			end

			if entry.l then
				l = l[eval_expr(SS, entry.l)[1]]
			end

			local res = table.pack(pcall(l, table.unpack(A)))
			if not table.remove(res, 1) then
				print("Call failed")
				SS:set_errored()
			else
				for i = 1, #res, 1 do
					table.insert(O, res[i])
				end
			end
		end,
		["?"] = function()
			local T = eval_expr(SS, entry.C)[1]
			if T then
				if entry.t then
					local IS = stack_push_do(SS)
					local o = eval_expr(IS, entry.t)
					for i = 1, #o, 1 do
						table.insert(O, o[i])
					end
				end
			else
				if entry.f then
					local IS = stack_push_do(SS)
					local o = eval_expr(IS, entry.f)
					for i = 1, #o, 1 do
						table.insert(O, o[i])
					end
				end
			end
		end,
		["W"] = function()
			while eval_expr(SS, entry.C)[1] do
				local WS = stack_push_loop(SS)
				for i = 1, #entry, 1 do
					eval_expr(WS, entry[i])
					if not WS:evaluate() then break end
				end

				if WS:is_break() then break end
			end
		end,
		["f"] = function()
			if entry["in"] then
				for a1, a2, a3, a4, a5, a6, a7, a8, a9 in table.unpack(eval_expr(SS, entry["in"])) do
					local FS = stack_push_loop(SS)
					local r = { a1, a2, a3, a4, a5, a6, a7, a8, a9 }
					for i = 1, #entry.A, 1 do
						FS:add(entry.A[i])
						FS.stack[entry.A[i]] = r[i]
					end

					for i = 1, #entry, 1 do
						eval_expr(FS, entry[i])
						if not FS:evaluate() then break end
					end

					if FS:is_break() then break end
				end
			else
				local s = eval_expr(SS, entry.s)[1]
				local e = eval_expr(SS, entry.e)[1]
				local _i = eval_expr(SS, entry.i)[1]
				for I = s, e, _i do
					local FS = stack_push_loop(SS)
					FS:add(entry.n)
					FS.stack[entry.n] = I

					for i = 1, #entry, 1 do
						eval_expr(FS, entry[i])
						if not FS:evaluate() then break end
					end

					if FS:is_break() then break end
				end
			end
		end,
		["B"] = function()
			for i = 1, #entry, 1 do
				eval_expr(SS, entry[i])
				if not SS:evaluate() then break end
			end
		end,
		["t"] = function()
			for i = 1, #entry, 1 do
				local o = eval_expr(SS, entry[i])
				for I = 1, #o, 1 do
					table.insert(O, o[I])
				end
			end
		end,
		["R"] = function()
			local A = {}

			for I = 1, #entry, 1 do
				local o = eval_expr(SS, entry[I])
				for i = 1, #o, 1 do
					table.insert(A, o[i])
				end
			end

			SS:set_return(A)
		end,
		["b"] = function()
			SS:set_break()
		end,
		["c"] = function()
			SS:set_continue()
		end,
		["+"] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l + r)
		end,
		["-"] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l - r)
		end,
		["*"] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l * r)
		end,
		["/"] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l / r)
		end,
		["^"] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l ^ r)
		end,
		[".."] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l .. r)
		end,
		["|"] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l | r)
		end,
		["&"] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l & r)
		end,
		["~"] = function()
			if #entry == 1 then
				table.insert(O, ~eval_expr(SS, entry[1])[1])
			else
				local l = eval_expr(SS, entry[1])[1]
				local r = eval_expr(SS, entry[2])[1]

				table.insert(O, l ~ r)
			end
		end,
		["#"] = function()
			for i=1,#entry,1 do
				table.insert(O, #eval_expr(SS, entry[i])[1])
			end
		end,
		[">>"] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l >> r)
		end,
		["<<"] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l << r)
		end,
		["%"] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l % r)
		end,
		[">"] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l > r)
		end,
		["<"] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l < r)
		end,
		["=="] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l == r)
		end,
		[">="] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l >= r)
		end,
		["<="] = function()
			local l = eval_expr(SS, entry[1])[1]
			local r = eval_expr(SS, entry[2])[1]

			table.insert(O, l <= r)
		end,
	}

	local c = VT[entry.T]
	if c then c() else print("Invalid: ", entry.T) end

	return O
end

local function execute(context, expr)
	local stack = create_stack(context)
	return table.unpack(eval_expr(stack, expr))
end

return {
	execute = execute,
}
