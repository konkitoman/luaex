local executor = require("./executor")

local tests = {
	["function"] = function()
		local context = {}
		executor.execute(context, { 6, {}, {} })()
		assert(executor.execute(context, { 6, { "a" }, { { 4, { { { "a" } } } } } })(32) == 32)
	end,
	["global function"] = function()
		local context = {}
		executor.execute(context, { 2, { { { "testing" } } }, { { 6, {}, {} } } })
		context.testing()
	end,
	["global function, implicit return"] = function()
		local context = {}
		executor.execute(context, { 2, { { { "implicit" } } }, { { 6, { "a" }, { { 4, { { { "a" } } } } } } } })
		assert(context.implicit(32) == 32)
	end,
	["global function, implicit return, variadic"] = function()
		local context = {}
		executor.execute(context, { 2, { { { "implicit" } } }, { { 6, {}, { { 5 } } } } })
		local a, b, c = context.implicit(32, 60)
		assert(a == 32 and b == 60 and c == nil)
		executor.execute(
			context,
			{ 2, { { { "implicit" } } }, { { 6, { "slf" }, { { 4, { { { "slf" } } } }, { 5 } } } } }
		)
		a, b, c = nil, nil, nil
		a, b, c = context.implicit(32, 60)
		assert(a == 60 and b == nil and c == nil)
	end,
	["function, return"] = function()
		local context = {}
		executor.execute(
			context,
			{ 2, { { { "returns" } } }, { { 6, { "a" }, { { 15, { { 4, { { { "a" } } } } } } } } } }
		)
		assert(context.returns(32) == 32)
	end,
	["call"] = function()
		local was_called = false
		local fn = function()
			was_called = true
		end

		local context = { to_call = fn }
		executor.execute(context, { 8, { 4, { { { "to_call" } } } }, {} })

		assert(was_called)
	end,
	["call, check"] = function()
		local was_called = false
		local fn = function(a)
			was_called = a == 21
		end

		local context = { to_call = fn }
		executor.execute(context, { 8, { 4, { { { "to_call" } } } }, { { 7, 21 } } })

		assert(was_called)
	end,
	["call, dynamic"] = function()
		local was_called = false
		local fn = function(a)
			was_called = a == 21
		end

		local context = { fn = fn, to_call = "fn" }
		executor.execute(context, { 8, { 4, { { { { 4, { { { "to_call" } } } } } } } }, { { 7, 21 } } })

		assert(was_called)
	end,
	["if"] = function()
		local context = {}
		local t = { 7, "This was true" }
		local f = { 7, "This was false" }
		assert(executor.execute(context, { 9, { 7, true }, t, f }) == "This was true")
		assert(executor.execute(context, { 9, { 7, false }, t, f }) == "This was false")
		assert(executor.execute(context, { 9, { 7, "Something" }, t, f }) == "This was true")
		assert(executor.execute(context, { 9, { 7 }, t, f }) == "This was false")
		assert(executor.execute(context, { 9, { 7, 0 }, t, f }) == "This was true")
		assert(executor.execute(context, { 9, { 7 }, t, f }) == "This was false")
		assert(executor.execute(context, { 9, { 17, { 7, true } }, t, f }) == "This was false")
		assert(executor.execute(context, { 9, { 17, { 7, false } }, t, f }) == "This was true")
	end,
	["while"] = function()
		local context = { a = 1 }
		executor.execute(context, {
			10,
			{ 37, { 4, { { { "a" } } } }, { 7, 20 } },
			{ { 2, { { { "a" } } }, { { 18, { 4, { { { "a" } } } }, { 7, 1 } } } } },
		})
		assert(context.a == 20)
	end,
	["while, break"] = function()
		local context = { a = 1 }
		executor.execute(context, {
			10,
			{ 37, { 4, { { { "a" } } } }, { 7, 20 } },
			{
				{ 9, { 35, { 4, { { { "a" } } } }, { 7, 10 } }, { 16 }, { 7 } },
				{ 2, { { { "a" } } }, { { 18, { 4, { { { "a" } } } }, { 7, 1 } } } },
			},
		})
		assert(context.a == 10)
	end,
	["for in"] = function()
		local context = { pairs = pairs, sum = 0, isum = 0 }
		executor.execute(context, {
			12,
			{
				8,
				{ 4, { { { "pairs" } } } },
				{ { 7, { 5, 5, 3, 4, 5, 6 } } },
			},
			{ "i", "v" },
			{
				{ 2, { { { "isum" } } }, { { 18, { 4, { { { "isum" } } } }, { 4, { { { "i" } } } } } } },
				{ 2, { { { "sum" } } }, { { 18, { 4, { { { "sum" } } } }, { 4, { { { "v" } } } } } } },
			},
		})
		assert(context.sum == 28)
		assert(context.isum == 21)
	end,
	["for in, break"] = function()
		local context = { pairs = pairs, sum = 0, isum = 0 }
		executor.execute(context, {
			12,
			{
				8,
				{ 4, { { { "pairs" } } } },
				{ { 7, { 5, 5, 3, 10, 4, 5, 6 } } },
			},
			{ "i", "v" },
			{
				{ 9, { 35, { 4, { { { "v" } } } }, { 7, 10 } }, { 16 }, { 7 } },
				{ 2, { { { "isum" } } }, { { 18, { 4, { { { "isum" } } } }, { 4, { { { "i" } } } } } } },
				{ 2, { { { "sum" } } }, { { 18, { 4, { { { "sum" } } } }, { 4, { { { "v" } } } } } } },
			},
		})
		assert(context.sum == 13)
		assert(context.isum == 6)
	end,
	["for i=1,10,1 do"] = function()
		local context = { sum = 0 }
		executor.execute(context, {
			11,
			{ 7, 1 },
			{ 7, 10 },
			{ 7, 1 },
			"i",
			{
				{
					2,
					{ { { "sum" } } },
					{ { 18, { 4, { { { "sum" } } } }, { 4, { { { "i" } } } } } },
				},
			},
		})
		assert(context.sum == 55)
	end,
	["for i=1,10,1 do, break"] = function()
		local context = { sum = 0 }
		executor.execute(context, {
			11,
			{ 7, 1 },
			{ 7, 10 },
			{ 7, 1 },
			"i",
			{
				{ 9, { 35, { 4, { { { "i" } } } }, { 7, 5 } }, { 16 }, { 7 } },
				{
					2,
					{ { { "sum" } } },
					{ { 18, { 4, { { { "sum" } } } }, { 4, { { { "i" } } } } } },
				},
			},
		})
		assert(context.sum == 10)
	end,
	["table"] = function()
		local context = { a = 20, b = 53 }
		local r = executor.execute(context, {
			3,
			{ { 7, "a" }, { 7, "b" } },
			{ { 4, { { { "a" } } } }, { 4, { { { "b" } } } } },
		})

		assert(r.a == context.a)
		assert(r.b == context.b)
	end,
	["table, function"] = function()
		local context = {}
		local r = executor.execute(context, {
			3,
			{ { 7, "test" } },
			{ { 6, {}, {} } },
		})
		r.test()
	end,
	["table, function, self, return"] = function()
		local context = { a = 20, b = 53 }
		local r = executor.execute(context, {
			3,
			{ { 7, "a" }, { 7, "test" } },
			{ { 7, 20 }, { 6, { "self" }, { { 4, { { { "self", "a" } } } } } } },
		})
		assert(r:test() == 20)
	end,
	["table, indirect set"] = function()
		local context = { table = {} }
		executor.execute(context, { 2, { { { 1 }, { 4, { { { "table" } } } } } }, { { 7, 21 } } })
		assert(context.table[1] == 21)
	end,
	["table, indirect get"] = function()
		local context = { table = { "nice" } }
		local r = executor.execute(context, { 4, { { { 1 }, { 4, { { { "table" } } } } } } })
		assert(r == "nice")
	end,
}

local fails = 0
local passed = 0
for i, test in pairs(tests) do
	print(string.format("\x1B[;33mRunning: \x1B[;39m%s", i))
	local s, err = pcall(test)
	if not s then
		print("\t\x1B[;31mFailed\x1B[;39m")
		print(err)
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
