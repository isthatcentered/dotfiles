local M = {}

local function get_main_branch()
  -- Try symbolic-ref first (most reliable)
  local ref = vim.fn.system 'git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null'
  if vim.v.shell_error == 0 then
    return ref:match('refs/remotes/origin/(.+)'):gsub('%s+', '')
  end
  -- Fallback: check if origin/main or origin/master exists
  vim.fn.system 'git rev-parse --verify origin/main 2>/dev/null'
  if vim.v.shell_error == 0 then
    return 'main'
  end
  vim.fn.system 'git rev-parse --verify origin/master 2>/dev/null'
  if vim.v.shell_error == 0 then
    return 'master'
  end
  return nil
end

local function get_current_branch()
  local branch = vim.fn.system 'git rev-parse --abbrev-ref HEAD 2>/dev/null'
  if vim.v.shell_error == 0 then
    return branch:gsub('%s+', '')
  end
  return nil
end

local function get_branch_commits(main, current)
  local args = {
    'git',
    'log',
    '--format=%H%x1f%h%x1f%cr%x1f%s',
  }

  if current == main then
    vim.list_extend(args, { '-n', '20', 'HEAD' })
  else
    table.insert(args, 'origin/' .. main .. '..HEAD')
  end

  local lines = vim.fn.systemlist(args)
  if vim.v.shell_error ~= 0 then
    return nil
  end

  local commits = {}
  for _, line in ipairs(lines) do
    local hash, short_hash, relative_date, subject = line:match '^([^\31]+)\31([^\31]+)\31([^\31]+)\31(.*)$'
    if hash then
      table.insert(commits, {
        hash = hash,
        short_hash = short_hash,
        relative_date = relative_date,
        subject = subject,
      })
    end
  end

  return commits
end

local function get_commit_parent(commit)
  local parent = vim.fn.systemlist { 'git', 'rev-parse', commit.hash .. '^' }
  if vim.v.shell_error ~= 0 or parent[1] == nil then
    return nil
  end

  return parent[1]
end

local DiffView = {
  'sindrets/diffview.nvim',
  config = function()
    local diffview = require 'diffview'
    local diffview_indent_buffers = {}

    local function is_diffview_indent_hidden(bufnr)
      for _, buffers in pairs(diffview_indent_buffers) do
        if buffers[bufnr] then
          return true
        end
      end

      return false
    end

    local function refresh_indent_guides(bufnr)
      local ok, ibl = pcall(require, 'ibl')
      if ok and ibl.initialized then
        ibl.refresh(bufnr)
      end
    end

    local function hide_indent_guides(bufnr)
      local tabpage = vim.api.nvim_get_current_tabpage()
      diffview_indent_buffers[tabpage] = diffview_indent_buffers[tabpage] or {}
      diffview_indent_buffers[tabpage][bufnr] = true
      refresh_indent_guides(bufnr)
    end

    local function restore_indent_guides(view)
      local buffers = diffview_indent_buffers[view.tabpage]
      diffview_indent_buffers[view.tabpage] = nil

      if buffers == nil then
        return
      end

      for bufnr in pairs(buffers) do
        if vim.api.nvim_buf_is_valid(bufnr) and not is_diffview_indent_hidden(bufnr) then
          refresh_indent_guides(bufnr)
        end
      end
    end

    local ok, hooks = pcall(require, 'ibl.hooks')
    if ok then
      hooks.register(hooks.type.ACTIVE, function(bufnr)
        return not is_diffview_indent_hidden(bufnr)
      end)
    end

    local function set_diff_winhl(winid, replacements)
      local parts = {}

      for item in vim.wo[winid].winhighlight:gmatch '[^,]+' do
        local from = item:match '^([^:]+):'
        if from and not replacements[from] then
          table.insert(parts, item)
        end
      end

      for from, to in pairs(replacements) do
        table.insert(parts, from .. ':' .. to)
      end

      vim.wo[winid].winhighlight = table.concat(parts, ',')
    end

    diffview.setup {
      enhanced_diff_hl = true,
      view = {
        default = {
          diff_args = { '--ignore-all-space', '-U99999' },
        },
        merge_tool = {
          diff_args = { '--ignore-all-space', '-U99999' },
        },
        file_history = {
          diff_args = { '--ignore-all-space', '-U99999' },
        },
      },
      hooks = {
        diff_buf_read = function()
          hide_indent_guides(vim.api.nvim_get_current_buf())

          local fillchars = vim.opt_local.fillchars:get()
          fillchars.diff = ' '
          vim.opt_local.fillchars = fillchars

          vim.opt_local.foldenable = true
          vim.opt_local.foldlevel = 0
          vim.cmd 'normal! zM'
          vim.opt_local.relativenumber = true
        end,
        diff_buf_win_enter = function(_, winid, ctx)
          if not ctx.layout_name:match '^diff2' then
            return
          end

          if ctx.symbol == 'a' then
            set_diff_winhl(winid, {
              DiffAdd = 'DiffviewOldLine',
              DiffDelete = 'DiffviewMissingLine',
              DiffChange = 'DiffviewOldLine',
              DiffText = 'DiffviewOldText',
            })
          elseif ctx.symbol == 'b' then
            set_diff_winhl(winid, {
              DiffAdd = 'DiffviewNewLine',
              DiffChange = 'DiffviewNewLine',
              DiffText = 'DiffviewNewText',
              DiffDelete = 'DiffviewMissingLine',
            })
          end
        end,
        view_opened = function(view)
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(view.tabpage)) do
            vim.wo[win].relativenumber = true
          end
          vim.keymap.set('n', 'q', function()
            if vim.api.nvim_get_current_tabpage() == view.tabpage then
              vim.cmd 'DiffviewClose'
            end
          end, { desc = 'Close diffview' })

          -- Auto-close diffview when leaving its tab
          vim.api.nvim_create_autocmd('TabLeave', {
            once = true,
            callback = function()
              vim.print 'close'
              vim.cmd 'DiffviewClose'
            end,
          })
        end,
        view_closed = restore_indent_guides,
      },
    }

    vim.keymap.set('n', '<leader>gc', function()
      local main = get_main_branch()
      local current = get_current_branch()
      if main == nil or current == main then
        vim.cmd 'DiffviewFileHistory'
      else
        vim.cmd('DiffviewFileHistory --range=origin/' .. main .. '..HEAD')
      end
    end, { desc = 'Branch commit history' })

    vim.keymap.set('n', '<leader>gf', function()
      vim.cmd 'DiffviewFileHistory %'
    end, { desc = 'File history' })

    vim.keymap.set('n', '<leader>ga', function()
      -- Update main branch to compare against latest changes
      local main = get_main_branch()
      if main == nil then
        vim.notify('No remote main branch found', vim.log.levels.WARN)
        return
      end
      -- vim.cmd('!git fetch origin ' .. main)
      vim.cmd('DiffviewOpen origin/' .. main)
    end, { desc = 'Diff against main branch' })

    vim.keymap.set('n', '<leader>gb', function()
      local main = get_main_branch()
      local current = get_current_branch()
      if main == nil or current == nil then
        vim.notify('No git branch found', vim.log.levels.WARN)
        return
      end

      local commits = get_branch_commits(main, current)
      if commits == nil then
        vim.notify('Could not list git commits', vim.log.levels.ERROR)
        return
      end

      if #commits == 0 then
        vim.notify('No branch commits found', vim.log.levels.INFO)
        return
      end

      vim.ui.select(commits, {
        prompt = 'Select commit to diff from:',
        format_item = function(commit)
          return commit.short_hash .. ' ' .. commit.subject .. ' (' .. commit.relative_date .. ')'
        end,
      }, function(commit)
        if commit == nil then
          return
        end

        local parent = get_commit_parent(commit)
        if parent == nil then
          vim.notify('Could not find parent commit for ' .. commit.short_hash, vim.log.levels.ERROR)
          return
        end

        vim.cmd('DiffviewOpen ' .. parent)
      end)
    end, { desc = 'Diff branch since selected commit' })

    vim.keymap.set('n', '<leader>gs', function()
      vim.cmd 'DiffviewOpen'
    end, { desc = 'Diff unstaged changes' })

    vim.keymap.set('n', '<leader>gF', function()
      local current_dir = vim.fn.expand '%:p:h'
      vim.cmd('DiffviewFileHistory ' .. current_dir)
    end, { desc = 'Folder history' })

    vim.keymap.set('n', '<leader>gq', function()
      vim.cmd 'DiffviewClose'
    end, { desc = 'Close diffview' })

    local function commit_changes(message)
      vim.notify('Committing...', vim.log.levels.INFO)
      local stderr_chunks = {}
      local command = 'git add -A && git commit -m ' .. vim.fn.shellescape(message)

      vim.fn.jobstart(command, {
        on_stderr = function(_, data)
          for _, line in ipairs(data) do
            if line ~= '' then
              table.insert(stderr_chunks, line)
            end
          end
        end,
        on_exit = function(_, code)
          vim.schedule(function()
            if code == 0 then
              vim.notify('Commit done', vim.log.levels.INFO)
            else
              local msg = table.concat(stderr_chunks, '\n')
              vim.notify(msg ~= '' and msg or 'Commit failed', vim.log.levels.ERROR)
            end
          end)
        end,
      })
    end

    local function open_commit_message_popup()
      local input_buf = vim.api.nvim_create_buf(false, true)
      local width = math.min(72, math.max(20, math.floor(vim.o.columns * 0.6)))
      width = math.min(width, math.max(1, vim.o.columns - 4))
      local row = math.max(0, math.floor((vim.o.lines - 3) / 2))
      local col = math.max(0, math.floor((vim.o.columns - width) / 2))

      vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { '' })
      vim.bo[input_buf].bufhidden = 'wipe'
      vim.bo[input_buf].buftype = 'nofile'
      vim.bo[input_buf].filetype = 'gitcommit'

      local input_win = vim.api.nvim_open_win(input_buf, true, {
        relative = 'editor',
        width = width,
        height = 1,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = ' Commit message ',
        title_pos = 'center',
      })

      local function close_popup()
        if vim.api.nvim_win_is_valid(input_win) then
          vim.api.nvim_win_close(input_win, true)
        end
        if vim.api.nvim_buf_is_valid(input_buf) then
          vim.api.nvim_buf_delete(input_buf, { force = true })
        end
      end

      local function submit()
        local message = vim.trim(vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)[1] or '')
        close_popup()

        if message == '' then
          return
        end

        commit_changes(message)
      end

      vim.keymap.set('i', '<CR>', submit, { buffer = input_buf, silent = true, nowait = true, desc = 'Commit' })
      vim.keymap.set('n', '<CR>', submit, { buffer = input_buf, silent = true, nowait = true, desc = 'Commit' })
      vim.keymap.set('n', 'q', close_popup, { buffer = input_buf, silent = true, nowait = true, desc = 'Cancel commit' })

      vim.cmd 'startinsert'
    end

    vim.keymap.set('n', '<leader>gy', function()
      vim.notify('Committing and pushing...', vim.log.levels.INFO)
      local stderr_chunks = {}
      vim.fn.jobstart('git add -A && git commit -m "wip" && git push -u origin HEAD', {
        on_stderr = function(_, data)
          for _, line in ipairs(data) do
            if line ~= '' then
              table.insert(stderr_chunks, line)
            end
          end
        end,
        on_exit = function(_, code)
          vim.schedule(function()
            if code == 0 then
              vim.notify('Commit and push done', vim.log.levels.INFO)
            else
              local msg = table.concat(stderr_chunks, '\n')
              vim.notify(msg ~= '' and msg or 'Commit or push failed', vim.log.levels.ERROR)
            end
          end)
        end,
      })
    end, { desc = 'Git yollo (commit all + push)' })

    vim.keymap.set('n', '<leader>gm', open_commit_message_popup, { desc = 'Git commit with message (commit all)' })
  end,
}

local GitSigns = {
  'lewis6991/gitsigns.nvim',
  config = function()
    require('gitsigns').setup()
  end,
}

local colors = {
  black = '#000000',
  white = '#ffffff',
  red = '#ffcccc',
  green = '#c6ead8',
}

local NeoGit = {
  'NeogitOrg/neogit',
  keys = {
    { '<leader>gG', '<cmd>Neogit<cr>', desc = 'Show Neogit UI' },
    { '<leader>gc', '<cmd>Neogit commit<cr>', desc = 'Commit' },
  },
  opts = {
    integrations = {
      diffview = true,
      fzf_lua = true,
      telescope = false,
    },
    highlight = {

      italic = true, --
      bold = true, --
      underline = true, --
      -- bg0       = colors.red, -- Darkest background color
      -- bg1       = colors.red, -- Second darkest background color
      bg2 = colors.white, -- Second lightest background color
      -- bg3       = colors.red, -- Lightest background color
      -- grey      = colors.red, -- middle grey shade for foreground
      -- white     = colors.red, -- Foreground white (main text)

      -- red = '#000000', -- Foreground red
      -- bg_red = '#f4e7e7', -- Background red
      line_red = colors.red, -- Cursor line highlight for red regions
      --
      -- orange    = "", -- Foreground orange
      -- bg_orange = "", -- background orange
      -- yellow    = "", -- Foreground yellow
      -- bg_yellow = "", -- background yellow
      green = colors.black, -- Foreground green
      -- bg_green  = colors.green, -- Background green
      line_green = colors.green, -- Cursor line highlight for green regions
      -- cyan      = "", -- Foreground cyan
      -- bg_cyan   = "", -- Background cyan
      -- blue      = "", -- Foreground blue
      -- bg_blue   = colors.red, -- Background blue

      -- purple    = colors.red, -- Foreground purple
      -- bg_purple = colors.red, -- Background purple
      -- md_purple = colors.red, -- Background medium purple
    },
  },
}

local LazyGit = {
  'kdheepak/lazygit.nvim',
  keys = {
    { '<leader>gg', '<cmd>LazyGit<cr>', desc = 'LazyGit' },
  },
}

local function set_keys(keys)
  for _, key in ipairs(keys or {}) do
    vim.keymap.set('n', key[1], key[2], {
      desc = key.desc,
      silent = key.silent,
    })
  end
end

function M.setup()
  DiffView.config()
  GitSigns.config()
  require('neogit').setup(NeoGit.opts)
  set_keys(NeoGit.keys)
  set_keys(LazyGit.keys)
end

return M
