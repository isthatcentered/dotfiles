local api = vim.api

local M = {}

function M.current()
	local cursor = api.nvim_win_get_cursor(0)

	return {
		buffer_id = 0,
		cursor_position = {
			line = cursor[1] - 1,
			column = cursor[2],
		},
	}
end

return M
