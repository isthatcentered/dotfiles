local augroup = vim.api.nvim_create_augroup('isthatcentered_go', { clear = true })

local function typecheck()
  vim.cmd 'silent make!'
  vim.cmd 'cwindow'
end

vim.api.nvim_create_autocmd('FileType', {
  group = augroup,
  pattern = 'go',
  callback = function(event)
    vim.api.nvim_buf_call(event.buf, function()
      vim.cmd 'compiler go'
      vim.opt_local.makeprg = "go test -run='^$' ./..."
    end)

    vim.keymap.set('n', '<leader>ck', typecheck, { buffer = event.buf, desc = 'Go Type Check' })
  end,
})
