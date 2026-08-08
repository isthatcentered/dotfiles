return {
  'rcarriga/nvim-dap-ui',
  dependencies = {
    'mfussenegger/nvim-dap',
    'nvim-neotest/nvim-nio',
    'jay-babu/mason-nvim-dap.nvim',
    'leoluz/nvim-dap-go',
  },
  config = function()
    require('lazydev').setup {
      library = { 'nvim-dap-ui' },
    }

    require('dapui').setup()

    local dap = require 'dap'
    local dapui = require 'dapui'

    require('mason-nvim-dap').setup {
      automatic_installation = true,
      ensure_installed = { 'delve' },
      handlers = {},
    }

    require('dap-go').setup {
      delve = {
        detached = vim.fn.has 'win32' == 0,
      },
    }

    dap.listeners.before.attach.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.launch.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated.dapui_config = function()
      dapui.close()
    end
    dap.listeners.before.event_exited.dapui_config = function()
      dapui.close()
    end

    vim.keymap.set('n', '<leader>dt', function()
      dap.toggle_breakpoint()
    end, { desc = 'Toggle breakpoint' })

    vim.keymap.set('n', '<leader>dc', function()
      dap.continue()
    end, { desc = 'Continue' })

    vim.keymap.set('n', '<leader>dt', function()
      dap.toggle_breakpoint()
    end, { desc = 'Toggle breakpoint' })
  end,
}
