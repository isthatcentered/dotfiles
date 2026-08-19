return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'nvim-neotest/nvim-nio',
    'leoluz/nvim-dap-go',
  },
  config = function()
    require('lazydev').setup {
      library = { 'nvim-dap-ui' },
    }

    local dap = require 'dap'
    local dapui = require 'dapui'
    local dap_utils = require 'dap.utils'

    dapui.setup {}

    require('dap-go').setup {
      delve = {
        detached = vim.fn.has 'win32' == 0,
      },
    }

    local js_adapter = {
      type = 'server',
      host = '127.0.0.1',
      port = '${port}',
      executable = {
        command = 'js-debug-adapter',
        args = { '${port}', '127.0.0.1' },
      },
    }

    dap.adapters['pwa-node'] = js_adapter
    dap.adapters.node = js_adapter
    dap.adapters['pwa-chrome'] = js_adapter
    dap.adapters.chrome = js_adapter

    local js_filetypes = {
      'javascript',
      'javascriptreact',
      'typescript',
      'typescriptreact',
    }

    local js_configurations = {
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Launch current file',
        program = '${file}',
        cwd = '${workspaceFolder}',
        console = 'integratedTerminal',
        sourceMaps = true,
        skipFiles = { '<node_internals>/**' },
      },
      {
        type = 'pwa-node',
        request = 'attach',
        name = 'Attach to Node process',
        processId = dap_utils.pick_process,
        cwd = '${workspaceFolder}',
        sourceMaps = true,
        skipFiles = { '<node_internals>/**' },
      },
      {
        type = 'pwa-chrome',
        request = 'launch',
        name = 'Launch Chrome against localhost',
        url = function()
          return vim.fn.input('URL: ', 'http://localhost:3000')
        end,
        webRoot = '${workspaceFolder}',
        sourceMaps = true,
      },
    }

    for _, filetype in ipairs(js_filetypes) do
      dap.configurations[filetype] = js_configurations
    end

    local vscode = require 'dap.ext.vscode'
    for _, adapter_type in ipairs { 'node', 'pwa-node', 'chrome', 'pwa-chrome' } do
      vscode.type_to_filetypes[adapter_type] = js_filetypes
    end

    dap.listeners.after.event_initialized.dapui_config = function()
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
    end, { desc = 'Debug: Toggle breakpoint' })

    vim.keymap.set('n', '<leader>dc', function()
      dap.continue()
    end, { desc = 'Debug: Start/continue' })

    vim.keymap.set('n', '<leader>di', dap.step_into, { desc = 'Debug: Step into' })
    vim.keymap.set('n', '<leader>do', dap.step_over, { desc = 'Debug: Step over' })
    vim.keymap.set('n', '<leader>dO', dap.step_out, { desc = 'Debug: Step out' })
    vim.keymap.set('n', '<leader>db', function()
      dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
    end, { desc = 'Debug: Conditional breakpoint' })
    vim.keymap.set('n', '<leader>dl', dap.run_last, { desc = 'Debug: Run last' })
    vim.keymap.set('n', '<leader>dq', dap.terminate, { desc = 'Debug: Terminate' })
    vim.keymap.set('n', '<leader>dr', dap.repl.toggle, { desc = 'Debug: Toggle REPL' })
    vim.keymap.set('n', '<leader>du', dapui.toggle, { desc = 'Debug: Toggle UI' })
    vim.keymap.set('n', '<leader>dgt', require('dap-go').debug_test, { desc = 'Debug: Go test' })
    vim.keymap.set('n', '<leader>dgl', require('dap-go').debug_last_test, { desc = 'Debug: Last Go test' })
  end,
}
