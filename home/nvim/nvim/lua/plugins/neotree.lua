return {
  {
    'antosha417/nvim-lsp-file-operations',
    config = function()
      require('lsp-file-operations').setup {
        operations = {
          willRenameFiles = true,
          didRenameFiles = true,
          willCreateFiles = true,
          didCreateFiles = true,
          willDeleteFiles = true,
          didDeleteFiles = true,
        },
      }

      local neo_tree_events = require 'neo-tree.events'
      local write_all_after_file_operation = function()
        vim.cmd 'silent! wall'
      end

      neo_tree_events.subscribe {
        id = 'write_all_after_file_renamed',
        event = neo_tree_events.FILE_RENAMED,
        handler = write_all_after_file_operation,
      }

      neo_tree_events.subscribe {
        id = 'write_all_after_file_moved',
        event = neo_tree_events.FILE_MOVED,
        handler = write_all_after_file_operation,
      }
    end,
  },
}
