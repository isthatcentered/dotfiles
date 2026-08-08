local M = {}

local SmartSplits = {
  'mrjones2014/smart-splits.nvim',
  config = function()
    local smart_splits = require 'smart-splits'

    vim.keymap.set('n', '<C-b>h', smart_splits.move_cursor_left)
    vim.keymap.set('n', '<C-b>j', smart_splits.move_cursor_down)
    vim.keymap.set('n', '<C-b>k', smart_splits.move_cursor_up)
    vim.keymap.set('n', '<C-b>l', smart_splits.move_cursor_right)
  end,
}

function M.setup()
  SmartSplits.config()
end

return M
