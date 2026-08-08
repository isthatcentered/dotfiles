local M = {}

local function save_modified_buffers_for_file_operation(args)
  local utils = require 'neo-tree.utils'

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' and vim.bo[buf].modified then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if utils.is_subpath(args.source, buf_name) then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd 'silent! write!'
        end)
      end
    end
  end
end

local function close_neo_tree_on_file_open()
  require('neo-tree.command').execute { action = 'close' }
end

local NeoTree = {
  'nvim-neo-tree/neo-tree.nvim',
  config = function()
    require('neo-tree').setup {
      close_if_last_window = true,
      window = {
        width = 43,
      },
      event_handlers = {
        {
          event = 'neo_tree_buffer_enter',
          handler = function()
            vim.wo.number = true
            vim.wo.relativenumber = true
          end,
        },
        {
          event = 'file_open_requested',
          handler = close_neo_tree_on_file_open,
        },
        {
          event = 'before_file_move',
          handler = save_modified_buffers_for_file_operation,
        },
        {
          event = 'before_file_rename',
          handler = save_modified_buffers_for_file_operation,
        },
      },
      filesystem = {
        follow_current_file = {
          enabled = true,
        },
        use_libuv_file_watcher = true,
        window = {
          mappings = {
            ['C'] = 'close_all_subnodes',
            ['Z'] = 'expand_all_subnodes',
          },
        },
      },
    }

    vim.api.nvim_create_autocmd('VimLeavePre', {
      group = vim.api.nvim_create_augroup('IsThatCenteredNeoTreeExit', { clear = true }),
      callback = function()
        pcall(require('neo-tree.command').execute, { action = 'close' })
      end,
    })
  end,
}

function M.setup()
  NeoTree.config()
  vim.keymap.set('n', '\\', '<cmd>Neotree reveal<cr>', { desc = 'NeoTree reveal', silent = true })
  vim.keymap.set('n', '<leader>e', '<cmd>Neotree toggle<cr>', { desc = 'Toggle NeoTree', silent = true })
end

return M
