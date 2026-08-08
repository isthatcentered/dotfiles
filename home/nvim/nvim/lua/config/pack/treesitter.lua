local M = {}

local languages = {
  'c',
  'c_sharp',
  'go',
  'gomod',
  'gowork',
  'lua',
  'vim',
  'vimdoc',
  'query',
  'markdown',
  'markdown_inline',
  'json',
  'javascript',
  'tsx',
  'jsx',
  'typescript',
  'toml',
  'php',
  'yaml',
  'css',
  'html',
  'razor',
  'xml',
}

function M.setup()
  local filetypes = vim.list_extend(vim.deepcopy(languages), { 'cs' })
  local treesitter = require 'nvim-treesitter'

  treesitter.install(languages)
  treesitter.update(languages)

  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('native-treesitter-start', { clear = true }),
    pattern = filetypes,
    callback = function()
      vim.treesitter.start()
    end,
  })
end

function M.update()
  require('nvim-treesitter').update():wait(300000)
end

return M
