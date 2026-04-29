local executor = require("executor")
local frontend = require("frontend-lua")

local file_executor = io.open("executor.lua", "r")
local source_executor = file_executor:read("a")

local file_frontend = io.open("frontend-lua.lua", "r")
local source_frontend = file_frontend:read("a")

local function show_table(table, depth)
	depth = depth or 0
	if type(table) == "table" then
		local out = "{\n"
		for i, v in pairs(table) do
			if tonumber(i) then
				out = out .. string.format("%s[%s] = %s,\n", string.rep("    ", depth + 1), i, show_table(v, depth + 1))
			else
				out = out
					.. string.format('%s["%s"] = %s,\n', string.rep("    ", depth + 1), i, show_table(v, depth + 1))
			end
		end
		return out .. string.rep("    ", depth) .. "}"
	elseif type(table) == "string" then
		return string.format('"%s"', table)
	else
		return string.format("%s", table)
	end
end

local tokens_executor = frontend.parse(source_executor)
local ast_node_executor = frontend.ast_parse_module(tokens_executor)
local bytecode_executor = frontend.compile(ast_node_executor)

local tokens_frontend = frontend.parse(source_frontend)
local ast_node_frontend = frontend.ast_parse_module(tokens_frontend)
local bytecode_frontend = frontend.compile(ast_node_frontend)

local context = {
	print = print,
	table = table,
	math = math,
	pairs = pairs,
	ipairs = ipairs,
	string = string,
	tonumber = tonumber,
	type = type,
	pcall = pcall,
	error = error,
	assert = assert,
	setmetatable = setmetatable,
	show_table = show_table,
}

local vm_executor = executor.execute(context, bytecode_executor)()
local vm_frontend = executor.execute(context, bytecode_frontend)()

context.executor = vm_executor
context.frontend = vm_frontend

local file_test = io.open("test_lua.lua", "r")
local source_test = file_test:read("a")

local tokens_test = frontend.parse(source_test)
local ast_node_test = frontend.ast_parse_module(tokens_test)
local bytecode_test = frontend.compile(ast_node_test)

executor.execute(context, bytecode_test)()
