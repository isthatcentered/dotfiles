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

local function add_packaged_queries_to_runtimepath()
  local plugin = vim.pack.get({ 'nvim-treesitter' })[1]
  if not plugin then
    return
  end

  -- Keep the plugin's queries as a fallback when installed query links are stale.
  local query_runtime = vim.fs.joinpath(plugin.path, 'runtime')
  if not vim.list_contains(vim.opt.runtimepath:get(), query_runtime) then
    vim.opt.runtimepath:append(query_runtime)
  end
end

function M.setup()
  local filetypes = vim.list_extend(vim.deepcopy(languages), { 'cs' })
  local treesitter = require 'nvim-treesitter'

  add_packaged_queries_to_runtimepath()
  treesitter.install(languages)

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
