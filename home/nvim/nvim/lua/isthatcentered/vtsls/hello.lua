local M = {}

local registered_command = {}

local group = vim.api.nvim_create_augroup('isthatcentered-vtsls-autocommands', { clear = true })

function M.setup()
  local move_to_file_handler = require 'isthatcentered.vtsls.move_to_file'
  local config = require 'isthatcentered.vtsls.config'

  vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(args)
      if not args.data and not args.data.client_id then
        return
      end

      local client = vim.lsp.get_client_by_id(args.data.client_id)
      local bufnr = args.buf

      if not client or client.name ~= "ts_ls" then
        return
      end

      -- Register command
      local command_name = '_typescript.moveToFileRefactoring'
      if registered_command[command_name] then
        return
      end

      client.commands[command_name] = function(command, ctx)
        local client = vim.lsp.get_client_by_id(ctx.client_id)
        move_to_file_handler(client)(command)
      end
    end,
  })
end

return M
