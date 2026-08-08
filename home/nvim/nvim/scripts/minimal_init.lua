local plenary_dir = os.getenv 'PLENARY_DIR' or '/tmp/plenary.nvim'

if vim.fn.isdirectory(plenary_dir) == 0 then
  local result = vim.fn.system {
    'git',
    'clone',
    '--depth',
    '1',
    'https://github.com/nvim-lua/plenary.nvim',
    plenary_dir,
  }

  if vim.v.shell_error ~= 0 then
    print('Failed to clone plenary: ' .. result)
    os.exit(1)
  end
end

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.rtp = {
  vim.env.VIMRUNTIME,
  plenary_dir,
  '.',
}

vim.opt.packpath = {}
vim.opt.swapfile = false

vim.cmd 'runtime plugin/plenary.vim'
require 'plenary.busted'
