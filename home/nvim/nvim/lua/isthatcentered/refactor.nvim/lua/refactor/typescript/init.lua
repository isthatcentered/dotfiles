local inline_function = require("refactor.typescript.inline_function")
local replace_with_template_string = require("refactor.typescript.replace_with_template_string")

local M = {}

function M.inline_function(context)
	return inline_function.run(context)
end

function M.replace_with_template_string(context)
	return replace_with_template_string.run(context)
end

return M
