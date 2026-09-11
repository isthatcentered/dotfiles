-- Launch from anywhere: nvim -u /path/to/todo-prototype.nvim/scripts/minimal_init.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
vim.opt.termguicolors = true
vim.opt.mouse = 'a'
vim.opt.swapfile = false
require('todo_prototype').setup()
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    require('todo_prototype').open()
  end,
})
