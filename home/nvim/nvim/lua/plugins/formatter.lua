return {
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {},
    opts = {
      lsp_format = 'never',
      format_on_save = false,
      formatters_by_ft = {
        go = { 'goimports', 'gofmt' },
        lua = { 'stylua' },
        python = { 'isort', 'black' },
        rust = { 'rustfmt', lsp_format = 'fallback' },
        typescript = { 'oxfmt', 'prettierd', 'prettier', stop_after_first = true },
        typescriptreact = { 'oxfmt', 'prettierd', 'prettier', stop_after_first = true },
        javascript = { 'oxfmt', 'prettierd', 'prettier', stop_after_first = true },
        javascriptreact = { 'oxfmt', 'prettierd', 'prettier', stop_after_first = true },
        json = { 'jq' },
      },
    },
  },
}
