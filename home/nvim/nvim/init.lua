require('vim._core.ui2').enable {}
-- Basic settings
vim.opt.number = true -- Line numbers
vim.opt.relativenumber = true -- Relative line numbers
vim.opt.cursorline = true -- Highlight current line
vim.opt.wrap = false -- Don't wrap lines
vim.opt.scrolloff = 10 -- Keep 10 lines above/below cursor
vim.opt.sidescrolloff = 8 -- Keep 8 columns left/right of cursor

-- Indentation
vim.opt.tabstop = 2 -- Tab width
vim.opt.shiftwidth = 2 -- Indent width
vim.opt.softtabstop = 2 -- Soft tab stop
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.smartindent = true -- Smart auto-indenting
vim.opt.autoindent = true -- Copy indent from current line
vim.o.breakindent = true

-- Search settings
vim.opt.ignorecase = true -- Case insensitive search
vim.opt.smartcase = true -- Case sensitive if uppercase in search
vim.opt.hlsearch = true -- Do highlight search results
vim.opt.incsearch = true -- Show matches as you type

-- Visual settings
vim.opt.termguicolors = true -- Enable 24-bit colors
vim.opt.signcolumn = 'yes' -- Always show sign column
vim.opt.showmatch = true -- Highlight matching brackets
vim.o.inccommand = 'split' -- Preview substitutions live, as you type!
vim.o.cursorline = true
vim.o.winborder = 'rounded'

-- File handling
vim.opt.backup = false -- Don't create backup files
vim.opt.writebackup = false -- Don't create backup before writing
vim.opt.swapfile = false -- Don't create swap files
vim.opt.undofile = true -- Persistent undo
vim.opt.updatetime = 250 -- Faster completion
vim.opt.timeoutlen = 300 -- Key timeout duration
vim.opt.autoread = true -- Auto reload files changed outside vim
vim.opt.autowrite = false -- Let checktime + autosave drive writes explicitly

-- Behavior settings
vim.opt.nrformats:append 'alpha'
vim.opt.errorbells = false -- No error bells
vim.opt.mouse = 'a' -- Enable mouse support
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.confirm = true -- show confirm dialog when a file hasn't been saved
vim.opt.path:append '**' -- include sub directories in search

-- folding settings
-- https://www.jackfranklin.co.uk/blog/code-folding-in-vim-neovim/
vim.opt.foldmethod = 'expr' -- use expression for folding
vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.opt.foldcolumn = '0'
vim.opt.foldtext = ''
vim.opt.foldlevel = 99 -- start with all folds open
vim.opt.foldlevelstart = 99 -- start with all folds open
-- vim.opt.foldlevelstart = 1
vim.keymap.set('n', '(', 'zk', { desc = 'Go to previous fold start' })
vim.keymap.set('n', ')', 'zj', { desc = 'Go to next fold start' })

-- split behavior
vim.opt.splitbelow = true -- horizontal splits go below
vim.opt.splitright = true -- vertical splits go right

-- key mappings
vim.g.mapleader = ' ' -- set leader key to space
vim.g.maplocalleader = ' ' -- set local leader key (new)

vim.g.neovide_input_macos_alt_is_meta = true

-- normal mode mappings
vim.keymap.set('n', '<esc>', '<cmd>nohlsearch<cr>') -- clear search highlights when pressing <esc> in normal mode

-- center screen when jumping
vim.keymap.set('n', 'n', 'nzzzv', { desc = 'next search result (centered)' })
vim.keymap.set('n', 'n', 'nzzzv', { desc = 'previous search result (centered)' })

-- NAVIGATION  -----------------------------------------
-- Window navigation
vim.keymap.set('n', '<C-l>', '<c-w><c-w>', { desc = 'move focus to next window' })
-- vim.keymap.set('n', '<c-h>', '<c-w><c-w>', { desc = 'move focus to next window' })

-- Buffer navigation
vim.keymap.set('n', '<c-d>', '<c-d>zz', { desc = 'half page down (centered)' })
vim.keymap.set('n', '<c-u>', '<c-u>zz', { desc = 'half page up (centered)' })
vim.keymap.set('n', '<C-h>', ':b#<cr>', { desc = 'Go to alternate buffer' })

-- vim.keymap.set('n', '<C-j>', ':bnext<cr>', { desc = 'next buffer' })
-- vim.keymap.set('n', '<C-k>', ':bprevious<cr>', { desc = 'previous buffer' })

-- move lines up/down
-- vim.keymap.set('n', '<a-j>', ':m .+1<cr>==', { desc = 'move line down' })
-- vim.keymap.set('n', '<a-k>', ':m .-2<cr>==', { desc = 'move line up' })
-- vim.keymap.set('v', '<a-j>', ":m '>+1<cr>gv=gv", { desc = 'move selection down' })
-- vim.keymap.set('v', '<a-k>', ":m '<-2<cr>gv=gv", { desc = 'move selection up' })

-- -- better indenting in visual mode
-- vim.keymap.set('v', '<', '<gv', { desc = 'indent left and reselect' })
-- vim.keymap.set('v', '>', '>gv', { desc = 'indent right and reselect' })

-- quick file navigation
-- vim.keymap.set("n", "<leader>fe", ":explore<cr>", { desc = "open file explorer" })
-- vim.keymap.set("n", "<leader>ff", ":find ", { desc = "find file" })

-- lines
-- vim.keymap.set('n', '<leader>lj', 'mzj`z', { desc = 'join lines and keep cursor position' })

-- terminal
vim.keymap.set('t', '<esc>', '<c-\\><c-n>', { desc = 'exit terminal mode' })

-- ============================================================================
-- useful functions
-- ============================================================================
vim.api.nvim_create_autocmd('textyankpost', {
  desc = 'highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank { timeout = 500 }
  end,
})

-- use system clipboard
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

local augroup = vim.api.nvim_create_augroup('userconfig', {})

local function is_file_buffer(bufferId)
  local buffer = vim.bo[bufferId]

  return vim.api.nvim_buf_get_name(bufferId) ~= '' and buffer.buftype == ''
end

local function check_current_buffer_timestamp()
  local bufferId = vim.api.nvim_get_current_buf()

  if vim.fn.mode() == 'c' or not is_file_buffer(bufferId) then
    return
  end

  vim.cmd('checktime ' .. bufferId)
end

-- disable line numbers in terminal
vim.api.nvim_create_autocmd('termopen', {
  group = augroup,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
  end,
})

-- auto-resize splits when window is resized
vim.api.nvim_create_autocmd('vimresized', {
  group = augroup,
  callback = function()
    vim.cmd 'tabdo wincmd ='
  end,
})

vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained', 'TermClose', 'TermLeave' }, {
  group = augroup,
  callback = check_current_buffer_timestamp,
})

vim.api.nvim_create_autocmd('FileChangedShell', {
  group = augroup,
  callback = function(args)
    if not is_file_buffer(args.buf) then
      return
    end

    vim.v.fcs_choice = 'reload'

    vim.schedule(function()
      local fileName = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(args.buf), ':~:.')

      vim.notify('Reloaded externally changed file: ' .. fileName, vim.log.levels.WARN)
    end)
  end,
})

-- ============================================================================
-- Plugins
-- ============================================================================
require 'isthatcentered/load_custom_plugins'
require 'isthatcentered.diagnostics'
require 'isthatcentered.autosave'
require 'isthatcentered.autorun'
require 'isthatcentered.go'
require 'isthatcentered.review'
vim.opt.background = 'light'
vim.g.colors_name = 'acid'
require('acid').setup()
local pack = require 'config.pack'
pack.add()
pack.setup()
require 'config.lazy'
pack.setup_after_lazy()
require 'isthatcentered.focus_dimming'

vim.keymap.set('n', '<leader>ws', ':w<CR>:source %<CR>', { desc = 'Save & source' })

local lastClosedBuffer = nil
vim.api.nvim_create_user_command('BufferClose', function()
  lastClosedBuffer = vim.api.nvim_get_current_buf()
  vim.cmd 'bp'
  vim.cmd 'bd#'
end, {})
vim.api.nvim_create_user_command('BufferOpenLastClosed', function()
  if not lastClosedBuffer or not vim.api.nvim_buf_is_valid(lastClosedBuffer) then
    return
  end

  local currentWin = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(currentWin, lastClosedBuffer)
end, {})

vim.api.nvim_create_user_command('Shada', function()
  local shada_dir = vim.fn.stdpath 'state' .. '/shada'
  local pattern = shada_dir .. '/main.shada.tmp.*'
  local files = vim.fn.glob(pattern, false, true)

  if #files == 0 then
    vim.notify('No ShaDa temp files to clean', vim.log.levels.INFO)
    return
  end

  for _, file in ipairs(files) do
    os.remove(file)
  end

  vim.notify('Cleaned ' .. #files .. ' ShaDa temp files', vim.log.levels.INFO)
end, { desc = 'Clean orphaned ShaDa temp files' })

vim.keymap.set('n', '<M-w>', ':BufferClose<cr>', { desc = 'Close current buffer while keeping window open' })
vim.keymap.set('n', '<M-W>', ':BufferOpenLastClosed<cr>', { desc = 'Open last closed buffer' })

local lsp_utils = require 'isthatcentered.utils.lsp'
local lint_fixers = require 'isthatcentered.lint_fixers'
vim.api.nvim_create_user_command('IsThatCenteredFormatAction', function()
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo.filetype

  require('conform').format { async = false }

  local typescript_vtsls_client = vim.lsp.get_clients({ name = 'vtsls', buffnr = bufnr })[1]
  local typescript_ts_ls_client = vim.lsp.get_clients({ name = 'ts_ls', buffnr = bufnr })[1]
  local oxlint_client = vim.lsp.get_clients({ name = 'oxlint', buffnr = bufnr })[1]
  local eslint_client = vim.lsp.get_clients({ name = 'eslint', buffnr = bufnr })[1]

  local function run_lint_fixers(cb)
    lint_fixers.run {
      bufnr = bufnr,
      eslint_client = eslint_client,
      oxlint_client = oxlint_client,
      cb = cb,
    }
  end

  if not string.find(filetype, '^typescript') then
    run_lint_fixers(function() end)
    return
  end

  if typescript_vtsls_client then
    typescript_vtsls_client:exec_cmd({
      title = 'Remove unused imports',
      command = 'typescript.removeUnusedImports',
      arguments = {
        vim.api.nvim_buf_get_name(bufnr),
      },
    }, { bufnr = vim.api.nvim_get_current_buf() }, function()
      if not eslint_client then
        require('vtsls').commands.organize_imports(0, function()
          run_lint_fixers(function() end)
        end, function()
          run_lint_fixers(function() end)
        end)
        -- Add missing imports?
        return
      end

      run_lint_fixers(function() end)
    end)
    return
  end

  if typescript_ts_ls_client then
    -- {
    -- "source.fixAll.ts",
    -- "source.removeUnused.ts",
    -- "source.addMissingImports.ts",
    -- "source.organizeImports.ts",
    -- "source.removeUnusedImports.ts",
    -- "source.sortImports.ts",
    -- "quickfix",
    -- "refactor"

    -- TODO: retry automatically until the diagnostics i'm interested in aren't solved
    lsp_utils.run_code_actions {
      bufnr = bufnr,
      client = typescript_ts_ls_client,
      kinds = { 'source.addMissingImports.ts' },
      cb = function()
        lsp_utils.run_code_actions {
          bufnr = bufnr,
          client = typescript_ts_ls_client,
          kinds = { 'source.removeUnusedImports.ts' },
          cb = function()
            lsp_utils.run_code_actions {
              bufnr = bufnr,
              client = typescript_ts_ls_client,
              kinds = { 'source.organizeImports.ts' },
              cb = function()
                run_lint_fixers(function() end)
              end,
            }
          end,
        }
      end,
    }
    return
  end

  run_lint_fixers(function() end)

  -- vim.lsp.buf.code_action { apply = true, context = { only = { 'source.addMissingImports' }, diagnostics = {} } }

  -- if string.find(filetype, '^typescript') then
  --   local client = vim.lsp.get_clients({ name = 'vtsls', bufnr = 0 })[1]
  --
  --   vim.cmd 'LspEslintFixAll'
  --
  --   -- client:exec_cmd({
  --   --   title = 'Sort imports',
  --   --   command = 'typescript.sortImports',
  --   --   arguments = {
  --   --     vim.api.nvim_buf_get_name(bufferId),
  --   --   },
  --   -- }, { bufnr = vim.api.nvim_get_current_buf() })
  --
  --   -- client:exec_cmd({
  --   --   title = 'Remove unused imports',
  --   --   command = 'typescript.removeUnusedImports',
  --   --   arguments = {
  --   --     vim.api.nvim_buf_get_name(bufferId),
  --   --   },
  --   -- }, { bufnr = vim.api.nvim_get_current_buf() })
  -- end
end, {})

vim.api.nvim_create_user_command('IsThatCenteredImportAction', function()
  local bufferId = vim.api.nvim_get_current_buf()
  local buffer = vim.bo
  local filetype = vim.bo.filetype

  if string.find(filetype, '^typescript') then
    local client = vim.lsp.get_clients({ name = 'vtsls', bufnr = 0 })[1]

    -- vim.lsp.buf.code_action { apply = true, context = { only = { 'source.addMissingImports' }, diagnostics = {} } }
    -- vim.cmd 'LspEslintFixAll'

    -- client:exec_cmd({
    --   title = 'Sort imports',
    --   command = 'typescript.sortImports',
    --   arguments = {
    --     vim.api.nvim_buf_get_name(bufferId),
    --   },
    -- }, { bufnr = vim.api.nvim_get_current_buf() })

    client:exec_cmd({
      title = 'Remove unused imports',
      command = 'typescript.removeUnusedImports',
      arguments = {
        vim.api.nvim_buf_get_name(bufferId),
      },
    }, { bufnr = vim.api.nvim_get_current_buf() })
  end
end, {})

vim.keymap.set('n', '<leader>f', ':IsThatCenteredFormatAction<cr>', { desc = 'Code fixup actions' })
vim.keymap.set('n', 'gri', ':IsThatCenteredImportAction<CR>', { desc = 'Remove unused imports' })
vim.keymap.set('n', '<leader>ll', ':LspRestart<cr>', { desc = 'Restart lsp server' })

vim.keymap.set('n', '<leader>D', function()
  local visible_buffers = {}

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    visible_buffers[vim.api.nvim_win_get_buf(win)] = true
  end

  local closed_count = 0
  local failed_count = 0

  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) and vim.bo[buffer].buflisted and not visible_buffers[buffer] then
      local ok = pcall(vim.cmd.bdelete, buffer)

      if ok then
        closed_count = closed_count + 1
      else
        failed_count = failed_count + 1
      end
    end
  end

  local message = 'Closed ' .. closed_count .. ' hidden buffer'
  if closed_count ~= 1 then
    message = message .. 's'
  end

  if failed_count > 0 then
    message = message .. ', skipped ' .. failed_count .. ' modified buffer'
    if failed_count ~= 1 then
      message = message .. 's'
    end
  end

  vim.notify(message)
end, { desc = 'Close all buffers except displayed ones' })

---------------------------------------------------
-- UTilS shortcuts
---------------------------------------------------
vim.keymap.set('n', '<leader>ui', function()
  vim.print(vim.inspect_pos())
end, { desc = '[U]til [I]nspect extrmarks' })

vim.keymap.set('n', '<leader>uf', function()
  local path = vim.fn.expand '%:.'
  vim.fn.setreg('+', path)
  vim.print(path)
end, { desc = '[U]til [I]nspect extrmarks' })

vim.keymap.set('n', '<leader>ur', function()
  local function get_file_test_status(buffer_id)
    local neotest = require 'neotest'
    local adapters = neotest.state.adapter_ids()
    local overall_state = { running = false, failing = false }
    local is_attached = false
    local states = {}

    for _, adapter_id in pairs(adapters) do
      local state = neotest.state.status_counts(adapter_id, { buffer = buffer_id })
      if state then
        table.insert(states, state)
        is_attached = true
        overall_state.running = overall_state.running or state.running > 0
        overall_state.failing = overall_state.failing or state.failed > 0
      end
    end

    return states, adapters
  end
  vim.print(get_file_test_status(vim.api.nvim_get_current_buf()))
end, { desc = '[U]til [R]andom test' })

vim.keymap.set('n', '<leader>uC', function()
  vim.cmd 'set conceallevel=0'
end, { desc = '[U]til set [C]onceal level to 0' })

vim.keymap.set('n', '<leader>uc', function()
  vim.cmd 'set conceallevel=3'
end, { desc = '[U]til get current set [C]onceal level to 3' })

vim.keymap.set('n', '<leader>ub', function()
  local buffer_name = vim.api.nvim_buf_get_name(0)
  vim.print(vim.api.nvim_get_current_buf())
end, { desc = '[U]til get current [B]uffer id' })

vim.keymap.set('n', '<leader>uf', function()
  local relative_path = vim.fn.expand '%'
  vim.fn.setreg('+', relative_path) -- Copy to system clipboard
  vim.print(relative_path)
end, { desc = '[U]til get current [F]ile name' })

vim.keymap.set({ 'n', 'v' }, '<leader>ul', function()
  local relative_path = vim.fn.expand '%:p' -- '%' for relative
  -- Normal mode: use current line (1-indexed, which GitHub expects)
  local line = vim.fn.line '.'
  result = relative_path .. '#L' .. line

  vim.fn.setreg('+', result)
  vim.print(result)
end, { desc = '[U]til get current [L]ine or range' })

vim.keymap.set('n', '<leader>up', function()
  local full_path = vim.fn.expand '%:p'
  vim.fn.setreg('+', full_path) -- Copy to system clipboard
  vim.print(full_path)
end, { desc = '[U]til get current [P]ath' })

vim.keymap.set('n', '<leader>uw', function()
  local window_id = vim.api.nvim_get_current_win()

  vim.print(window_id)
end, { desc = '[U]til get current [W]indow id' })

vim.keymap.set('n', '<leader>um', function()
  vim.cmd "enew | put =execute('messages') | setlocal buftype=nofile bufhidden=wipe noswapfile"
end, { desc = '[U]til get current [W]indow id' })

-- @TODO: Auto save + custom format per language
-- TODO:  bnext only switches to buffers opened in this window
-- @TODO: have window layout presets ?
-- TODO: new file helper
--
-- local ScrollNamespace = vim.api.nvim_create_namespace 'IsThatCenteredScroll'
-- vim.api.nvim_set_hl(0, 'IsThatCenteredScrollStartMark', {})
--
-- ---@param config {timeout: number}
-- local function highlight_current_line(config)
--   local row = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-indexed
--
--   vim.hl.range(
--     0,
--     ScrollNamespace,
--     'Visual',
--     { row, 0 },
--     { row, -1 }, -- -1 = highlight to end of line
--     { timeout = config.timeout }
--   )
--
--   local neoscroll = require("neoscroll")
--   neoscroll.ctrl_u({})
--   vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-u>', true, false, true), 'm', true)
--   -- vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('zz', true, false, true), 'm', true)
-- end
--
-- vim.api.nvim_create_user_command('IsScroll', function()
--   highlight_current_line { timeout = 3000 }
-- end, {})
--
-- vim.keymap.set('n', '<leader>a', ':IsScroll<CR>', { desc = 'Code fixup actions' })

-- local initialRenameHandler = vim.lsp.handlers['textDocument/rename']
-- local blah2 = 123
-- vim.lsp.handlers['textDocument/rename'] = function(...)
--   initialRenameHandler(...)
--   vim.cmd ''
--   vim.notify 'Renamed:::'
-- end
--
-- Auto restore last session on startup
vim.api.nvim_create_autocmd('VimEnter', {
  group = vim.api.nvim_create_augroup('Persistence', { clear = true }),
  callback = function()
    -- NOTE: Before restoring the session, check:
    -- 1. No arg passed when opening nvim, means no `nvim --some-arg ./some-path`
    -- 2. No pipe, e.g. `echo "Hello world" | nvim`
    if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
      pcall(function()
        require('persistence').load()
      end)
    end
  end,
  -- HACK: need to enable `nested` otherwise the current buffer will not have a filetype(no syntax)
  nested = true,
})
-- local custom_lsp_handler = require 'isthatcentered.vtsls.hello'
-- custom_lsp_handler.setup()

-- vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
--   pattern = '*.ts',
--   callback = function()
--     -- vim.bo.filetype = "typescript"
--     vim.print(vim.treesitter.language.get_lang 'typescript')
-- vim.treesitter.language.register('typescript', 'typescriptreact')
--   end,
-- })

-- Enable local .nvim.lua files
vim.o.exrc = true
vim.o.secure = true
