local api = vim.api
local Context = require("refactor.context")
local Refactor = require("refactor")
local TypescriptRefactor = require("refactor.typescript")
local replace_with_template_string = require("refactor.typescript.replace_with_template_string")
local pack = table.pack or function(...)
	return {
		n = select("#", ...),
		...,
	}
end
local unpack = table.unpack or unpack

local function with_test_buffer(filetype, lines, cursor, callback)
	vim.cmd("enew!")

	local bufnr = api.nvim_create_buf(false, true)

	api.nvim_win_set_buf(0, bufnr)
	vim.bo[bufnr].buftype = ""
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.cmd("setfiletype " .. filetype)
	api.nvim_win_set_cursor(0, cursor)

	local result
	local ok, err = xpcall(function()
		result = pack(callback(bufnr))
	end, debug.traceback)

	vim.cmd("enew!")

	if api.nvim_buf_is_valid(bufnr) then
		api.nvim_buf_delete(bufnr, { force = true })
	end

	if not ok then
		error(err)
	end

	return unpack(result, 1, result.n)
end

local function normalize_error(err)
	local message = tostring(err):match("Refactor: [^\n]+")
	if message ~= nil then
		return message
	end

	message = tostring(err):match("E%d+: [^\n]+")
	if message ~= nil then
		return message
	end

	return tostring(err)
end

local function run_refactor(filetype, lines, cursor)
	return with_test_buffer(filetype, lines, cursor, function(bufnr)
		local ok, err = pcall(replace_with_template_string.run, {
			buffer_id = bufnr,
			cursor_position = {
				line = cursor[1] - 1,
				column = cursor[2],
			},
		})
		local error_message = nil
		if not ok then
			error_message = normalize_error(err)
		end

		return {
			lines = api.nvim_buf_get_lines(bufnr, 0, -1, false),
			cursor = api.nvim_win_get_cursor(0),
			error = error_message,
		}
	end)
end

describe("replace_with_template_string", function()
	it("rewrites a single-quoted typescript string when the cursor is on the opening quote", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const message = 'hello';",
			},
			cursor = { 1, 16 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const message = `hello`;",
			},
			cursor = { 1, 16 },
			error = nil,
		}, result)
	end)

	it("rewrites a double-quoted typescript string when the cursor is on the closing quote", function()
		local input = {
			filetype = "typescript",
			lines = {
				'const message = "hello";',
			},
			cursor = { 1, 22 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const message = `hello`;",
			},
			cursor = { 1, 22 },
			error = nil,
		}, result)
	end)

	it("rewrites jsx attribute strings in typescriptreact buffers", function()
		local input = {
			filetype = "typescriptreact",
			lines = {
				'const view = <div className="hello" />;',
			},
			cursor = { 1, 29 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const view = <div className={`hello`} />;",
			},
			cursor = { 1, 30 },
			error = nil,
		}, result)
	end)

	it("throws when the cursor is not inside a string", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const answer = 42;",
			},
			cursor = { 1, 15 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const answer = 42;",
			},
			cursor = { 1, 15 },
			error = "Refactor: Cursor is not inside a string",
		}, result)
	end)

	it("throws when the cursor is already inside a template string", function()
		local input = {
			filetype = "typescript",
			lines = {
				"const message = `hello`;",
			},
			cursor = { 1, 17 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				"const message = `hello`;",
			},
			cursor = { 1, 17 },
			error = "Refactor: Cursor is already inside a template string",
		}, result)
	end)

	it("throws for unsupported string content", function()
		local input = {
			filetype = "typescript",
			lines = {
				'const message = "hello ${name}";',
			},
			cursor = { 1, 18 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				'const message = "hello ${name}";',
			},
			cursor = { 1, 18 },
			error = "Refactor: Replace with template string does not support this string content yet",
		}, result)
	end)

	it("is unavailable outside typescript and typescriptreact buffers", function()
		local input = {
			filetype = "lua",
			lines = {
				'local message = "hello"',
			},
			cursor = { 1, 18 },
		}

		local result = run_refactor(input.filetype, input.lines, input.cursor)

		assert.same({
			lines = {
				'local message = "hello"',
			},
			cursor = { 1, 18 },
			error = "Refactor: Unsupported filetype 'lua'",
		}, result)
	end)
end)

describe("public api", function()
	it("exposes the refactor from the root and language namespaces", function()
		assert.equal(TypescriptRefactor.replace_with_template_string, Refactor.typescript.replace_with_template_string)
	end)

	it("builds current editor context from the root and helper module", function()
		with_test_buffer("typescript", {
			"const message = 'hello';",
		}, { 1, 16 }, function()
			assert.same(Context.current(), Refactor.context())
			assert.same({
				buffer_id = 0,
				cursor_position = {
					line = 0,
					column = 16,
				},
			}, Refactor.context())
		end)
	end)
end)
