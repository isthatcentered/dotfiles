local api = vim.api

local M = {}

local SUPPORTED_FILETYPES = {
	typescript = "typescript",
	typescriptreact = "tsx",
}
local UNSUPPORTED_CONTENT_ERROR = "Replace with template string does not support this string content yet"

local function raise(message)
	error("Refactor: " .. message, 0)
end

local function parser_language_for(filetype)
	return SUPPORTED_FILETYPES[filetype]
end

local function ensure_parser(bufnr, lang)
	vim.treesitter.start(bufnr, lang)
	vim.treesitter.get_parser(bufnr, lang):parse()
end

local function validate_context(context)
	if type(context) ~= "table" then
		raise("Context is required")
	end

	if context.buffer_id == nil then
		raise("Context buffer_id is required")
	end

	if type(context.cursor_position) ~= "table" then
		raise("Context cursor_position is required")
	end

	if type(context.cursor_position.line) ~= "number" then
		raise("Context cursor_position.line is required")
	end

	if type(context.cursor_position.column) ~= "number" then
		raise("Context cursor_position.column is required")
	end
end

local function resolve_buffer_id(buffer_id)
	if buffer_id == 0 then
		return api.nvim_get_current_buf()
	end

	return buffer_id
end

local function find_target_string(bufnr, lang, cursor_position)
	local node = vim.treesitter.get_node({
		bufnr = bufnr,
		lang = lang,
		pos = { cursor_position.line, cursor_position.column },
	})
	local string_node = nil

	while node do
		local node_type = node:type()
		if node_type == "template_string" then
			raise("Cursor is already inside a template string")
		end
		if string_node == nil and node_type == "string" then
			string_node = node
		end
		node = node:parent()
	end

	if string_node == nil then
		raise("Cursor is not inside a string")
	end

	return string_node
end

local function is_supported_content(content, start_row, end_row)
	if start_row ~= end_row then
		return false
	end

	return not content:find("`", 1, true) and not content:find("${", 1, true)
end

local function replacement_for(string_node, content)
	local parent = string_node:parent()
	if parent ~= nil and parent:type() == "jsx_attribute" then
		return "{`" .. content .. "`}", 1
	end

	return "`" .. content .. "`", 0
end

local function sync_cursor(bufnr, cursor_position, cursor_col_offset)
	if api.nvim_get_current_buf() ~= bufnr then
		return
	end

	api.nvim_win_set_cursor(0, {
		cursor_position.line + 1,
		cursor_position.column + cursor_col_offset,
	})
end

function M.run(context)
	validate_context(context)

	local bufnr = resolve_buffer_id(context.buffer_id)
	local filetype = vim.bo[bufnr].filetype
	local lang = parser_language_for(filetype)
	if lang == nil then
		raise(("Unsupported filetype '%s'"):format(filetype))
	end

	ensure_parser(bufnr, lang)

	local string_node = find_target_string(bufnr, lang, context.cursor_position)
	local start_row, start_col, end_row, end_col = string_node:range()
	local string_text = vim.treesitter.get_node_text(string_node, bufnr)
	local content = string_text:sub(2, -2)

	if not is_supported_content(content, start_row, end_row) then
		raise(UNSUPPORTED_CONTENT_ERROR)
	end

	local replacement, cursor_col_offset = replacement_for(string_node, content)
	api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { replacement })
	sync_cursor(bufnr, context.cursor_position, cursor_col_offset)
end

return M
