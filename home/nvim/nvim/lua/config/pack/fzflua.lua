local M = {}

local function buffer_dir()
  local dir = vim.fn.expand '%:p:h'
  if dir == '' then
    return vim.fn.getcwd()
  end
  return dir
end

local function strip_cwd(path)
  local cwd = vim.fn.getcwd()
  local prefix = cwd .. '/'

  if vim.startswith(path, prefix) then
    return path:sub(#prefix + 1)
  end

  return path
end

local FzfLua = {
  'ibhagwan/fzf-lua',
  config = function()
    local fzf = require 'fzf-lua'
    local actions = fzf.actions

    fzf.setup {
      ui_select = {},
      fzf_opts = {
        ['--cycle'] = true,
      },
      files = {
        hidden = true,
        no_ignore = false,
        fd_opts = '--color=never --type f --type l --hidden --exclude .git',
        rg_opts = '--color=never --files --hidden --glob !.git/*',
      },
      grep = {
        hidden = true,
        rg_glob = true,
        glob_flag = '--iglob',
        glob_separator = '%s%-%-',
        rg_opts = '--column --line-number --no-heading --color=always --smart-case --hidden --glob !.git/*',
      },
      oldfiles = {
        include_current_session = true,
      },
      keymap = {
        builtin = {
          true,
          ['<C-d>'] = 'preview-half-page-down',
          ['<C-u>'] = 'preview-half-page-up',
        },
        fzf = {
          true,
          ['ctrl-q'] = 'select-all+accept',
        },
      },
      buffers = {
        sort_lastused = true,
        actions = {
          ['ctrl-d'] = actions.buf_del,
        },
      },
    }

    local function find_all_files(opts)
      opts = opts or {}

      fzf.files {
        cwd = opts.cwd,
        query = opts.query,
        hidden = true,
        no_ignore = true,
        fd_opts = '--color=never --type f --type l --hidden --no-ignore --exclude .git',
        rg_opts = '--color=never --files --hidden --no-ignore --glob !.git/*',
      }
    end

    vim.keymap.set('n', '<leader>sh', fzf.helptags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sk', fzf.keymaps, { desc = '[S]earch [K]eymaps' })
    vim.keymap.set('n', '<leader>sf', fzf.files, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<leader>sF', find_all_files, { desc = '[S]earch all [F]iles' })

    vim.keymap.set('n', '<leader>sc', function()
      local dir = buffer_dir()
      if vim.startswith(dir, vim.fn.getcwd()) then
        fzf.files {
          hidden = true,
          query = strip_cwd(dir),
        }
        return
      end

      fzf.files {
        cwd = dir,
        hidden = true,
      }
    end, { desc = '[S]earch [C]urrent [F]iles' })

    vim.keymap.set('n', '<leader>sn', function()
      fzf.files {
        cwd = vim.env.HOME,
        cmd = 'fd --type f --strip-cwd-prefix --hidden --exclude .git . .config/nvim Test/nvim',
      }
    end, { desc = '[S]earch [N]vim files' })

    vim.keymap.set('n', '<leader>sG', fzf.git_status, { desc = '[S]earch [G]it status files' })
    vim.keymap.set('n', '<leader>sq', fzf.quickfix, { desc = '[S]earch [Q]uickfix list' })
    vim.keymap.set('n', '<leader>ss', fzf.lsp_workspace_symbols, { desc = '[S]earch LSP [S]ymbols' })
    vim.keymap.set('n', '<leader>st', fzf.builtin, { desc = '[S]earch [S]elect fzf-lua' })
    vim.keymap.set('n', '<leader>sw', fzf.grep_cword, { desc = '[S]earch current [W]ord' })
    vim.keymap.set('n', '<leader>sg', fzf.live_grep, { desc = '[S]earch by [G]rep' })
    vim.keymap.set('n', '<leader>G', function()
      fzf.live_grep { cwd = buffer_dir() }
    end, { desc = '[S]earch by [G]rep in current folder' })
    vim.keymap.set('n', '<leader>sd', fzf.diagnostics_workspace, { desc = '[S]earch [D]iagnostics' })
    vim.keymap.set('n', '<leader>sr', fzf.resume, { desc = '[S]earch [R]esume' })
    vim.keymap.set('n', '<leader>s.', fzf.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
    vim.keymap.set('n', '<leader>sb', fzf.buffers, { desc = '[S]earch opened [B]uffers' })
    vim.keymap.set('n', '<leader>sH', fzf.oldfiles, { desc = '[S]earch opened [H]istory' })
    vim.keymap.set('n', '<leader>sl', fzf.lsp_outgoing_calls, { desc = '[S]earch [L]sp outgoing calls' })
    vim.keymap.set('n', '<leader>s/', fzf.lines, { desc = '[S]earch [/] in Open Buffers' })

    vim.keymap.set('n', '<leader>sP', function()
      fzf.files { cwd = vim.fn.stdpath 'data' }
    end, { desc = '[S]earch [N]eovim [P]lugins' })
  end,
}

function M.setup()
  FzfLua.config()
end

return M
