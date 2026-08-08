local context = require("refactor.context")

local M = {
	typescript = require("refactor.typescript"),
}

function M.context()
	return context.current()
end

return M
