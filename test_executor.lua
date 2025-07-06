local executor = require("./executor")

local tests = {
	["function"] = function()
		local context = {}
		executor.execute(context, { T = "F", A = {} })()
		assert(executor.execute(context, { T = "F", A = { "a" }, { T = "@", { "a" } } })(32) == 32)
	end,
	["global function"] = function()
		local context = {}
		executor.execute(context, { T = "=", P = { { "testing" } }, { T = "F", A = {} } })
		context.testing()
	end,
	["global function, implicit return"] = function()
		local context = {}
		executor.execute(context, { T = "=", P = { { "implicit" } }, { T = "F", A = { "a" }, { T = "@", { "a" } } } })
		assert(context.implicit(32) == 32)
	end,
	["global function, implicit return, variadic"] = function()
		local context = {}
		executor.execute(context, { T = "=", P = { { "implicit" } }, { T = "F", A = {}, { T = "$" } } })
		local a, b, c = context.implicit(32, 60)
		assert(a == 32 and b == 60 and c == nil)
		executor.execute(context,
			{ T = "=", P = { { "implicit" } }, { T = "F", A = { "slf" }, { T = "t", { T = "@", { "slf" } }, { T = "$" } } } })
		a, b, c = nil, nil, nil
		a, b, c = context.implicit(32, 60)
		assert(a == 32 and b == 60 and c == nil)
	end,
	["function, return"] = function()
		local context = {}
		executor.execute(context,
			{ T = "=", P = { { "returns" } }, { T = "F", A = { "a" }, { T = "B", { T = "R", { T = "@", { "a" } } } } } })
		assert(context.returns(32) == 32)
	end,
	["call"] = function()
		local was_called = false
		local fn = function()
				was_called = true
		end

		local context = {to_call = fn}
		executor.execute(context, {T = "C", P = {"to_call"}})

		assert(was_called)
	end,
	["call, check"] = function()
		local was_called = false
		local fn = function(a)
				was_called = a == 21
		end

		local context = {to_call = fn}
		executor.execute(context, {T = "C", P = {"to_call"}, {T = "I", 21}})

		assert(was_called)
	end,
	["call, dynamic"] = function()
		local was_called = false
		local fn = function(a)
				was_called = a == 21
		end

		local context = {fn = fn, to_call = "fn"}
		executor.execute(context, {T = "C", P = {}, l = {T = "@", {"to_call"}}, {T = "I", 21}})

		assert(was_called)
	end,
	["if"] = function()
		local context = {}
		local t = { T = "I", "This was true" }
		local f = { T = "I", "This was false" }
		assert(executor.execute(context, { T = "?", C = { T = "I", true }, t = t, f = f }) == "This was true")
		assert(executor.execute(context, { T = "?", C = { T = "I", false }, t = t, f = f }) == "This was false")
		assert(executor.execute(context, { T = "?", C = { T = "I", "Something" }, t = t, f = f }) == "This was true")
		assert(executor.execute(context, { T = "?", C = { T = "I" }, t = t, f = f }) == "This was false")
		assert(executor.execute(context, { T = "?", C = { T = "I", 0 }, t = t, f = f }) == "This was true")
		assert(executor.execute(context, { T = "?", C = { T = "I" }, t = t, f = f }) == "This was false")
		assert(executor.execute(context, { T = "?", C = { T = "!", { T = "I", true } }, t = t, f = f }) == "This was false")
		assert(executor.execute(context, { T = "?", C = { T = "!", { T = "I", false } }, t = t, f = f }) == "This was true")
	end,
	["while"] = function()
		local context = { a = 1 }
		executor.execute(context,
			{ T = "W", C = { T = "<", { T = "@", { "a" } }, { T = "I", 20 } }, { T = "=", P = { { "a" } }, { T = "+", { T = "@", { "a" } }, { T = "I", 1 } } } })
		assert(context.a == 20)
		executor.execute(context,
			{ T = "W", C = { T = "<", { T = "@", { "a" } }, { T = "I", 20 } }, { T = "=", P = { { "a" } }, { T = "+", { T = "@", { "a" } }, { T = "I", 1 } } } })
		assert(context.a == 20)
	end,
	["while, break"] = function()
		local context = { a = 1 }
		executor.execute(context,
			{ T = "W", C = { T = "<", { T = "@", { "a" } }, { T = "I", 20 } }, { T = "?", C = { T = "==", { T = "@", { "a" } }, { T = "I", 10 } }, t = { T = "b" } }, { T = "=", P = { { "a" } }, { T = "+", { T = "@", { "a" } }, { T = "I", 1 } } } })
		assert(context.a == 10)
	end,
	["while, continue"] = function()
		local context = { a = 1, b = 1 }
		executor.execute(context,
			{
				T = "W",
				C = { T = "<", { T = "@", { "a" } }, { T = "I", 20 } },
				{ T = "=", P = { { "a" } },                                         { T = "+", { T = "@", { "a" } }, { T = "I", 1 } } },
				{ T = "?", C = { T = "==", { T = "@", { "b" } }, { T = "I", 10 } }, t = { T = "c" } },
				{ T = "=", P = { { "b" } },                                         { T = "+", { T = "@", { "b" } }, { T = "I", 1 } } },
			})
		assert(context.a == 20 and context.b == 10)
	end,
	["for in"] = function()
		local context = { pairs = pairs, sum = 0, isum = 0 }
		executor.execute(context, {
			T = "f",
			["in"] = {
				T = "C",
				P = { "pairs" },
				{ T = "I", { 5, 5, 3, 4, 5, 6 } }
			},
			A = { "i", "v" },
			{ T = "=", P = { { "isum" } }, { T = "+", { T = "@", { "isum" } }, { T = "@", { "i" } } } },
			{ T = "=", P = { { "sum" } },  { T = "+", { T = "@", { "sum" } }, { T = "@", { "v" } } } },
		})
		assert(context.sum == 28)
		assert(context.isum == 21)
	end,
	["for in, break"] = function()
		local context = { pairs = pairs, sum = 0, isum = 0 }
		executor.execute(context, {
			T = "f",
			["in"] = {
				T = "C",
				P = { "pairs" },
				{ T = "I", { 5, 5, 3, 10, 4, 5, 6 } }
			},
			A = { "i", "v" },
			{ T = "?", C = { T = "==", { T = "@", { "v" } }, { T = "I", 10 } }, t = { T = "b" } },
			{ T = "=", P = { { "isum" } },                                      { T = "+", { T = "@", { "isum" } }, { T = "@", { "i" } } } },
			{ T = "=", P = { { "sum" } },                                       { T = "+", { T = "@", { "sum" } }, { T = "@", { "v" } } } },
		})
		assert(context.sum == 13)
		assert(context.isum == 6)
	end,
	["for in, continue"] = function()
		local context = { pairs = pairs, sum = 0, isum = 0 }
		executor.execute(context, {
			T = "f",
			["in"] = {
				T = "C",
				P = { "pairs" },
				{ T = "I", { 5, 5, 3, 10, 4, 5, 6 } }
			},
			A = { "i", "v" },
			{ T = "=", P = { { "sum" } },                                       { T = "+", { T = "@", { "sum" } }, { T = "@", { "v" } } } },
			{ T = "?", C = { T = "==", { T = "@", { "v" } }, { T = "I", 10 } }, t = { T = "c" } },
			{ T = "=", P = { { "isum" } },                                      { T = "+", { T = "@", { "isum" } }, { T = "@", { "i" } } } },
		})
		assert(context.sum == 38)
		assert(context.isum == 24)
	end,
	["for i=1,10,1 do"] = function()
		local context = { sum = 0 }
		executor.execute(context, {
			T = "f",
			s = { T = "I", 1 },
			e = { T = "I", 10 },
			i = { T = "I", 1 },
			n = "i",
			{
				T = "=",
				P = { { "sum" } },
				{ T = "+", { T = "@", { "sum" } }, { T = "@", { "i" } } }
			}
		})
		assert(context.sum == 55)
	end,
	["for i=1,10,1 do, break"] = function()
		local context = { sum = 0 }
		executor.execute(context, {
			T = "f",
			s = { T = "I", 1 },
			e = { T = "I", 10 },
			i = { T = "I", 1 },
			n = "i",
			{ T = "?", C = { T = "==", { T = "@", { "i" } }, { T = "I", 5 } }, t = { T = "b" } },
			{
				T = "=",
				P = { { "sum" } },
				{ T = "+", { T = "@", { "sum" } }, { T = "@", { "i" } } }
			}
		})
		assert(context.sum == 10)
	end,
	["for i=1,10,1 do, continue"] = function()
		local context = { sum = 0 }
		executor.execute(context, {
			T = "f",
			s = { T = "I", 1 },
			e = { T = "I", 10 },
			i = { T = "I", 1 },
			n = "i",
			{ T = "?", C = { T = "==", { T = "@", { "i" } }, { T = "I", 5 } }, t = { T = "c" } },
			{
				T = "=",
				P = { { "sum" } },
				{ T = "+", { T = "@", { "sum" } }, { T = "@", { "i" } } }
			}
		})
		assert(context.sum == 50)
	end,
	["table"] = function()
		local context = { a = 20, b = 53 }
		local r = executor.execute(context, {
			T = "T",
			{ { T = "I", "a" }, { T = "@", { "a" } } },
			{ { T = "I", "b" }, { T = "@", { "b" } } },
		})

		assert(r.a == context.a)
		assert(r.b == context.b)
	end,
	["table, function"] = function()
		local context = {}
		local r = executor.execute(context, {
			T = "T",
			{ { T = "I", "test" }, { T = "F", A = {} } },
		})
		r.test()
	end,
	["table, function, self, return"] = function()
		local context = { a = 20, b = 53 }
		local r = executor.execute(context, {
			T = "T",
			{ { T = "I", "a" },    { T = "I", 20 } },
			{ { T = "I", "test" }, { T = "F", A = { "self" }, { T = "@", { "self", "a" } } } },
		})
		assert(r:test() == 20)
	end
}

local fails = 0
local passed = 0
for i, test in pairs(tests) do
	print(string.format("\x1B[;33mRunning: \x1B[;39m%s", i))
	if not pcall(test) then
		print("\t\x1B[;31mFailed\x1B[;39m")
		fails = fails + 1
	else
		print("\t\x1B[;32mSuccess\x1B[;39m")
		passed = passed + 1
	end
end

print(string.format("\x1B[;1mTotal:\t%d\x1B[;39m", fails + passed))
print(string.format("\x1B[;32mPassed:\t%d\x1B[;39m", passed))
if fails > 0 then
	print(string.format("\x1B[;31mFails:\t%d\x1B[;39m", fails))
end
