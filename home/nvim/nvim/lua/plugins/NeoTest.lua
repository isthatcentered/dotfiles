local autocommands_group = vim.api.nvim_create_augroup('IsThatCenteredNeotestCommands', { clear = true })

local function open_output_panel()
  local origin_window = vim.api.nvim_get_current_win()
  local buffer_id = vim.api.nvim_get_current_buf()
  local window_id = vim.api.nvim_open_win(buffer_id, true, {
    split = 'right',
    vertical = true,
    focusable = false,
  })
  vim.print(window_id)

  vim.cmd 'wincmd L'

  vim.api.nvim_set_current_win(origin_window)

  --- Move to next window immediately
  vim.api.nvim_create_autocmd('WinEnter', {
    callback = function(event)
      local entered_window_id = vim.api.nvim_get_current_win()
      if entered_window_id ~= window_id then
        return
      end

      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('G', true, false, true), 'x', true)
      vim.cmd 'wincmd w'
    end,
    group = autocommands_group,
  })

  --- Auto close window if still opened on quit
  vim.api.nvim_create_autocmd('ExitPre', {
    callback = function()
      if vim.api.nvim_win_is_valid(window_id) then
        vim.api.nvim_win_close(window_id, true)
      end
    end,
    group = autocommands_group,
  })

  --- Remove all linked listeners
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = { tostring(window_id) },
    callback = function()
      vim.api.nvim_clear_autocmds { group = autocommands_group }
    end,
    group = autocommands_group,
  })

  return window_id
end

local NeoTest = {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',
    'marilari88/neotest-vitest',
    'nvim-neotest/neotest-plenary',
  },
  config = function()
    local neotest = require 'neotest'
    neotest.setup {

      output_panel = {
        enabled = true,
        open = open_output_panel,
      },
      consumers = {},
      adapters = {
        require 'neotest-vitest' {
          -- TODO: help this thing find the config
          filter_dir = function(name, rel_path, root)
            return name ~= 'node_modules'
          end,
        },
        require 'neotest-plenary',
      },
    }

    vim.keymap.set('n', '<M-S-k>', function()
      neotest.jump.prev { status = 'failed' }
    end, { desc = '[N]eotest [P]revious' })

    vim.keymap.set('n', '<M-S-j>', function()
      neotest.jump.next { status = 'failed' }
    end, { desc = '[N]eotest [N]next' })

    vim.keymap.set('n', '<leader>nt', function()
      neotest.summary.toggle()
    end, { desc = '[N]eotest [T]oggle' })

    vim.keymap.set('n', '<leader>nf', function()
      neotest.watch.watch(vim.fn.expand '%')
    end, { desc = '[N]eotest watch [F]ile' })

    vim.keymap.set('n', '<leader>nw', function()
      neotest.watch.watch()
    end, { desc = '[N]eotest [W]atch' })

    vim.keymap.set('n', '<leader>no', function()
      neotest.output.open()
    end, { desc = '[N]eotest [O]utput' })

    vim.keymap.set('n', '<leader>ns', function()
      neotest.watch.stop()
    end, { desc = '[N]eotest [S]top Watching' })

    vim.keymap.set('n', '<leader>np', function()
      neotest.output_panel.toggle()
    end, { desc = '[N]eotest [P]anel' })

vim.keymap.set('n', '<leader>ni', function()
      neotest.run.run {
        vim.fn.expand '%', --
        -- vitestCommand = 'npx vitest --config config/vitest.integration.config.ts',
        vitestCommand = 'npx vitest',
      }
    end, { desc = '[N]eotest watch [F]ile' })

    vim.keymap.set('n', '<leader>nu', function()
      neotest.run.run {
        vim.fn.expand '%', --
        -- vitestCommand = 'npx vitest --config config/vitest.unit.config.ts',
        vitestCommand = 'npx vitest',
      }
    end, { desc = '[N]eotest watch [F]ile' })
    -- vim.api.nvim_set_keymap(
    --   'n',
    --   '<leader>nv',
    --   "<cmd>lua require('neotest').run.run({ vim.fn.expand('%'),  })<CR>",
    --   { desc = 'Run Watch File' }
    -- )
  end,
}

return { }
