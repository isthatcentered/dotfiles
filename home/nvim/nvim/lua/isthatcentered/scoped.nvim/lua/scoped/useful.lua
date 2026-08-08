vim.print(vim.api.nvim_get_autocmds({ group = vim.api.nvim_create_augroup("scope:picker", { force = true }) }))

-- Listen to the quit event for a specific windwo
vim.api.nvim_create_autocmd({ "WinClosed" }, {
  pattern = { "" .. window_id },
  once = true,
  group = PickerCommandsGroup,
  callback = function()
    self:close()
  end,
})

local file_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_lines(buffer_id, cursor_row - 1, cursor_row, false)[1], ":p")
