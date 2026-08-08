local M = {}

-- TODO: get editor specs

function M.get_window_specs(window_id)

  return {
    id = window_id,
    buffer_id = vim.api.nvim_get_current_buf(),
    width =vim.api.nvim_win_get_width(window_id),
    height =vim.api.nvim_win_get_height(window_id)
  }
end

function M.get_active_window_specs()
  return M.get_window_specs(vim.api.nvim_get_current_win())
end

return M
