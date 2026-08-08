local acid = require 'acid'

local group = vim.api.nvim_create_augroup('acid-focus-dimming', { clear = true })

vim.api.nvim_create_autocmd('FocusLost', {
  group = group,
  desc = 'Dim the Acid theme when Neovim loses focus',
  callback = function()
    acid.set_variant 'dimmed'
  end,
})

vim.api.nvim_create_autocmd('FocusGained', {
  group = group,
  desc = 'Restore the Acid theme when Neovim gains focus',
  callback = function()
    acid.set_variant 'normal'
  end,
})
