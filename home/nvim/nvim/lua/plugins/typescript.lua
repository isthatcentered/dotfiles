local Typecheck = {
  'jellydn/typecheck.nvim',
  dependencies = { 'folke/trouble.nvim', dependencies = { 'nvim-tree/nvim-web-devicons' } },
  ft = { 'javascript', 'javascriptreact', 'json', 'jsonc', 'typescript', 'typescriptreact' },
  opts = {
    debug = true,
    mode = 'trouble', -- "quickfix" | "trouble"
  },
  keys = {
    {
      '<leader>ck',
      '<cmd>Typecheck<cr>',
      desc = 'Run Type Check',
    },
  },
}

local TSC = {
  'dmmulroy/tsc.nvim',
  config = function()
    require('tsc').setup {

      auto_open_qflist = true,
      auto_close_qflist = true,
      auto_focus_qflist = false,
      auto_start_watch_mode = false,
      use_trouble_qflist = false,
      use_diagnostics = false,
      run_as_monorepo = false,
      bin_name = 'tsgo',
      enable_progress_notifications = true,
      enable_error_notifications = true,
      flags = {
        noEmit = true,
        -- project = function()
        --   return utils.find_nearest_tsconfig()
        -- end,
        watch = false,
      },
      hide_progress_notifications_from_history = true,
      pretty_errors = true,
    }


    vim.keymap.set("n", "<leader>ck", ":TSC<CR>")
  end,
}

return {
  TSC
}
