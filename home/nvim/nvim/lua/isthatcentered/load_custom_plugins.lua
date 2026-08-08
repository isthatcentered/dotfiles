local PERSONAL_PLUGINS_PATH = vim.fn.stdpath 'config' .. '/lua/isthatcentered'
local PERSONAL_PLUGINS = {
  { name = 'acid', opts = {} },
  -- { name = 'snitch', opts = {} },
  {
    name = 'beacon2',
    config = function()
      local beacon = require 'beacon'

      beacon.setup {}
    end,
  },
  {
    name = 'scoped',
    config = function()
      local scoped = require('scoped').instance()

      vim.keymap.set('n', '<leader><leader>', function()
        scoped:toggle()
      end, { desc = 'Open ListsEditor' })

      vim.keymap.set('n', '<C-j>', function()
        scoped:next_in_current_window()
      end, { desc = 'Go to next file in lit' })

      vim.keymap.set('n', '<C-k>', function()
        scoped:previous_in_current_window()
      end, { desc = 'Go to prev in current window' })

      vim.keymap.set('n', 'sfa', function()
        scoped:add_current_file_to_current_list()
      end, { desc = 'Add current file to current list' })

      vim.keymap.set('n', 'sfr', function()
        scoped:remove_current_file_from_current_list()
      end, { desc = 'Remove current file from current list' })

      vim.keymap.set('n', 'sff', function()
        if scoped:has_bound_list(vim.api.nvim_get_current_win()) then
          scoped:add_current_file_to_current_list()
          return
        end

        local list_name = scoped:generate_scratch_name 'scratch_list'
        scoped:create_list(list_name)
        scoped:bind_current_window_to_list(list_name)
        scoped:add_current_file_to_current_list()
      end, { desc = 'Add the current file to the current list. If there is not current list, create one' })

      vim.keymap.set('n', 'slr', function()
        scoped:unbind_current_list_from_window()
      end, { desc = 'Unbind the list associated to the window' })

      vim.keymap.set('n', 'sa', function()
        scoped:add_current_file_to_current_list()
      end, { desc = 'Add current file to current list' })
    end,
  },
  {
    name = 'nope',
    config = function()
      local nope = require 'nope'

      local RunConfiguration = require 'nope.RunConfiguration'
      local make_default_label = require 'nope.make_default_label'
      local VitestAdapter = require 'nope.vitest.VitestAdapter'
      local PlenaryAdapter = require 'nope.plenary.PlenaryAdapter'
      local WindowConsumer = require 'nope.consumers.WindowConsumer'
      local DiagnosticsConsumer = require 'nope.consumers.DiagnosticsConsumer.init'

      local vitest_adapter = VitestAdapter.new()
      local plenary_adapter = PlenaryAdapter.new()

      nope.setup { --
        adapters = { vitest_adapter, plenary_adapter },
      }

      local window_consumer = WindowConsumer.make(
        function(cb)
          return nope.listen(cb)
        end, --
        function(cmd)
          if cmd.type == 'NopeStopRun' then
          else
            error('Unknown nope command: ' .. cmd.type)
          end
        end
      )

      DiagnosticsConsumer.new(function(cb)
        return nope.listen(cb)
      end)

      vim.api.nvim_create_autocmd({ 'VimLeavePre' }, {
        callback = function()
          window_consumer:close()
        end,
      })

      vim.keymap.set('n', '<leader>np', function()
        window_consumer:toggle()
      end, { desc = 'Toggle run view' })

      vim.keymap.set('n', '<leader>ns', function()
        nope.stop_all()
      end, { desc = 'Stop all runnng tests' })

      vim.keymap.set('n', '<leader>nf', function()
        local file_path = vim.fn.expand '%:.' -- Expand file path relative to current working directory
        local file_name = vim.fn.expand '%:t'
        local config_path = nil

        if vim.endswith(file_name, '.unit.test.ts') then
          config_path = 'config/vitest.unit.config.ts'
        elseif vim.endswith(file_name, '.integration.test.ts') then
          config_path = 'config/vitest.integration.config.ts'
        elseif vim.endswith(file_name, '.ts') then
          config_path = 'vitest.config.ts'
        else
          error('Unknow test file ' .. file_name)
        end

        -- Return closest vitest config from file
        -- File path = file_path - config path

        -- vim.print({
        --   config_path = config_path,
        --   file_path = file_path,
        --   cwd = vim.uv.cwd(),
        -- })
        --
        nope.start_run(RunConfiguration.new('Vitest', {
          label = file_name,
          watch = true,
          configuration_path = config_path,
          file_path = file_path,
        }))
      end, { desc = 'Run single file unit test' })

      -- vim.keymap.set('n', '<leader>nu', function()
      --   nope.start_run(RunConfiguration.new('Vitest', {
      --     label = 'Unit:All',
      --     watch = true,
      --     configuration_path = 'config/vitest.unit.config.ts',
      --   }))
      -- end, { desc = 'Run all unit tests' })
    end,
  },
}

for _, plugin in pairs(PERSONAL_PLUGINS) do
  vim.opt.rtp:prepend(PERSONAL_PLUGINS_PATH .. '/' .. plugin.name .. '.nvim')
  if plugin.opts then
    require(plugin.name).setup(plugin.opts)
  else
    plugin.config()
  end
end
