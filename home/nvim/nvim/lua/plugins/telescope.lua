-- local telescope_actions = require 'telescope.actions'
-- local telescope_state = require 'telescope.actions.state'
-- local harpoon = require 'harpoon'

return {
  {
    'nvim-telescope/telescope.nvim',
    enabled = false,
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },
      -- { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      require('telescope').setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        defaults = {
          path_display = { 'smart' },
          mappings = {
            -- i = { ['<c-enter>'] = require 'telescope.actions.' },
            n = {
              -- Add shortcut to add a file to harpoon
              -- ['<C-a>'] = function(prompt_buffnr)
              --   --- @type {[1]: string, cwd: string}
              --   local highlighted_entry = telescope_state.get_selected_entry()
              --   -- vim.print(highlighted_entry)
              --   local relative_file_path = highlighted_entry[1]
              --   local default_harpoon_list = harpoon:list()
              --   local existing_match = default_harpoon_list:get_by_value(relative_file_path)
              --
              --   if existing_match then
              --     default_harpoon_list:remove(existing_match)
              --
              --     vim.notify('File ' .. relative_file_path .. ' removed from harpoon')
              --   else
              --     default_harpoon_list:add {
              --       context = { col = 0, row = 1 },
              --       value = relative_file_path,
              --     }
              --     vim.notify('File ' .. relative_file_path .. ' added to harpoon')
              --   end
              -- end,
            },
          },
        },
        pickers = {
          find_files = {
            hidden = true,
            no_ignore = false,
            find_command = {
              'rg',
              '--files',
              '--color',
              'never',
              '--glob',
              '!.git/*',
            },
          },
          live_grep = {
            hidden = true,
            additional_args = { '--glob', '!.git/*' },
          },
          grep_string = {
            hidden = true,
            additional_args = { '--glob', '!.git/*' },
          },
          buffers = {
            show_all_buffers = true,
            sort_lastused = true,
            mappings = {
              n = {
                ['dd'] = 'delete_buffer',
              },
            },
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      local utils = require 'telescope.utils'
      local function find_all_files(opts)
        opts = opts or {}

        builtin.find_files {
          cwd = opts.cwd,
          default_text = opts.default_text,
          find_command = {
            'fd',
            '--type',
            'f',
            '--strip-cwd-prefix',
            '--hidden',
            '--exclude',
            '.git',
          },
        }
      end

      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', function()
        builtin.find_files {
          -- hidden = true,
        }
      end, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>sF', find_all_files, { desc = '[S]earch all [F]iles' })

      vim.keymap.set('n', '<leader>sc', function()
        if string.match(utils.buffer_dir(), vim.fn.getcwd()) then
          builtin.find_files {
            hidden = true,
            default_text = string.gsub(utils.buffer_dir(), vim.fn.getcwd() .. '/', ''),
          }
          return
        end

        builtin.find_files {
          cwd = utils.buffer_dir(),
          hidden = true,
        }
      end, { desc = '[S]earch [C]urrent [F]iles' })

      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files {
          cwd = vim.env.HOME,
          search_dirs = {
            '.config/nvim',
            'Test/nvim',
          },
        }
      end, { desc = '[S]earch [N]vim files' })

      -- vim.keymap.set('n', '<leader>sf', function()
      --   builtin.find_files { hidden = true, no_ignore = false}
      -- end, { desc = '[S]earch [F]iles' })

      vim.keymap.set('n', '<leader>sG', builtin.git_status, { desc = '[S]earch [G]it status files' })
      vim.keymap.set('n', '<leader>sq', builtin.quickfix, { desc = '[S]earch [Q]uickfix list' })
      vim.keymap.set('n', '<leader>ss', builtin.lsp_workspace_symbols, { desc = '[S]earch LSP [S]ymbols' })
      vim.keymap.set('n', '<leader>st', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sb', builtin.buffers, { desc = '[S]earch opened [B]uffers' })
      vim.keymap.set('n', '<leader>sH', builtin.oldfiles, { desc = '[S]earch opened [H]istory' })
      vim.keymap.set('n', '<leader>sl', builtin.lsp_outgoing_calls, { desc = '[S]earch [L]sp outgoing calls' })

      -- Slightly advanced example of overriding default behavior and theme
      -- vim.keymap.set('n', '/', function()
      --   -- You can pass additional configuration to Telescope to change the theme, layout, etc.
      --   builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
      --
      --     winblend = 10,
      --     previewer = false,
      --   })
      -- end, { desc = '[/] Fuzzily search in current buffer' })
      --
      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      -- Shortcut for searching your Neovim configuration files
      -- vim.keymap.set('n', '<leader>sn', function()
      --   builtin.find_files { cwd = vim.fn.stdpath 'config' }
      -- end, { desc = '[S]earch [N]eovim files' })

      -- Shortcut for searching your Neovim plugin files
      vim.keymap.set('n', '<leader>sP', function()
        builtin.find_files { cwd = vim.fn.stdpath 'data' }
      end, { desc = '[S]earch [N]eovim [P]lugins' })

      -- Shortcut for searching your Neovim theme files
      -- vim.keymap.set('n', '<leader>sp', function()
      --   builtin.find_files { cwd = '~/Test/nvim' }
      -- end, { desc = '[S]earch custom [P]lugins' })
    end,
  },
}
