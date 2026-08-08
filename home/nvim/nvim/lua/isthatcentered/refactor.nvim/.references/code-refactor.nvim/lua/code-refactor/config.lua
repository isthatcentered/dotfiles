return {
  format = function(opt)
    vim.lsp.buf.format(opt)
  end,
  available_actions = {
    javascript = {
      file_types = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    },
    php = {
      file_types = { "php" },
    },
  },
}
