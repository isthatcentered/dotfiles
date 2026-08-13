local M = {}

local preview_window_option = '@leaf_preview_window'
local preview_file_option = '@leaf_preview_file'
local preview_origin_option = '@leaf_preview_origin_pane'

local function notify_error(message)
  vim.notify(message, vim.log.levels.ERROR)
end

local function run_tmux(command)
  local ok, process = pcall(vim.system, command, { text = true })
  if not ok then
    return nil, tostring(process)
  end

  local result = process:wait()
  if result.code == 0 then
    return vim.trim(result.stdout or '')
  end

  local detail = vim.trim(result.stderr or '')
  return nil, detail ~= '' and detail or 'tmux command failed'
end

local function clear_origin_metadata(origin_pane)
  run_tmux { 'tmux', 'set-option', '-pqu', '-t', origin_pane, preview_window_option }
  run_tmux { 'tmux', 'set-option', '-pqu', '-t', origin_pane, preview_file_option }
end

local function close_preview_window(origin_pane, target, clear_before_close)
  if clear_before_close then
    clear_origin_metadata(origin_pane)
  end

  local _, error_message = run_tmux { 'tmux', 'kill-window', '-t', target }
  if error_message then
    notify_error('Could not close Leaf preview: ' .. error_message)
    return false
  end

  if not clear_before_close then
    clear_origin_metadata(origin_pane)
  end

  return true
end

local function get_existing_preview(origin_pane)
  local preview_window = run_tmux { 'tmux', 'show-options', '-pqv', '-t', origin_pane, preview_window_option }
  if not preview_window or preview_window == '' then
    return nil
  end

  local metadata = run_tmux {
    'tmux',
    'display-message',
    '-p',
    '-t',
    preview_window,
    '#{window_id}|#{@leaf_preview_origin_pane}|#{@leaf_preview_file}',
  }
  if not metadata then
    clear_origin_metadata(origin_pane)
    return nil
  end

  local window_id, recorded_origin, file_path = metadata:match '^([^|]*)|([^|]*)|(.*)$'
  if window_id ~= preview_window or recorded_origin ~= origin_pane then
    clear_origin_metadata(origin_pane)
    return nil
  end

  return { window = window_id, file = file_path }
end

local function create_preview_window(origin_pane, file_path)
  local origin_window, window_error = run_tmux { 'tmux', 'display-message', '-p', '-t', origin_pane, '#{window_id}' }
  local origin_directory, directory_error = run_tmux { 'tmux', 'display-message', '-p', '-t', origin_pane, '#{pane_current_path}' }
  if not origin_window or not origin_directory then
    notify_error('Could not inspect the originating tmux pane: ' .. (window_error or directory_error or 'unknown tmux error'))
    return
  end

  local window_name = 'leaf:' .. vim.fn.fnamemodify(file_path, ':t')
  local created, create_error = run_tmux {
    'tmux',
    'new-window',
    '-a',
    '-P',
    '-F',
    '#{window_id}|#{pane_id}',
    '-c',
    origin_directory,
    '-e',
    'DOTFILES_LEAF_PREVIEW=1',
    '-e',
    'DOTFILES_LEAF_ORIGIN_PANE=' .. origin_pane,
    '-n',
    window_name,
    '-t',
    origin_window,
    'exec nvim',
  }
  if not created then
    notify_error('Could not create Leaf preview window: ' .. create_error)
    return
  end

  local window_id, nvim_pane = created:match '^([^|]+)|([^|]+)$'
  if not window_id or not nvim_pane then
    notify_error 'Could not identify the Leaf preview window'
    return
  end

  local commands = {
    { 'tmux', 'set-option', '-pq', '-t', origin_pane, preview_window_option, window_id },
    { 'tmux', 'set-option', '-pq', '-t', origin_pane, preview_file_option, file_path },
    { 'tmux', 'set-option', '-wq', '-t', window_id, preview_origin_option, origin_pane },
    { 'tmux', 'set-option', '-wq', '-t', window_id, preview_file_option, file_path },
  }
  for _, command in ipairs(commands) do
    local _, metadata_error = run_tmux(command)
    if metadata_error then
      run_tmux { 'tmux', 'kill-window', '-t', window_id }
      clear_origin_metadata(origin_pane)
      notify_error('Could not initialize Leaf preview window: ' .. metadata_error)
      return
    end
  end

  local leaf_command = string.format('leaf --watch %s; tmux kill-window -t "$TMUX_PANE"', vim.fn.shellescape(file_path))
  local _, split_error = run_tmux {
    'tmux',
    'split-window',
    '-h',
    '-p',
    '50',
    '-t',
    nvim_pane,
    leaf_command,
  }
  if split_error then
    run_tmux { 'tmux', 'kill-window', '-t', window_id }
    clear_origin_metadata(origin_pane)
    notify_error('Could not start Leaf preview: ' .. split_error)
  end
end

local function toggle_preview(buffer)
  if not vim.env.TMUX or vim.env.TMUX == '' or not vim.env.TMUX_PANE or vim.env.TMUX_PANE == '' then
    notify_error 'Leaf preview requires Neovim to be running inside tmux'
    return
  end

  if vim.fn.executable 'tmux' == 0 then
    notify_error 'Leaf preview could not find tmux on PATH'
    return
  end

  if vim.env.DOTFILES_LEAF_PREVIEW == '1' then
    local origin_pane = vim.env.DOTFILES_LEAF_ORIGIN_PANE
    if origin_pane and origin_pane ~= '' then
      close_preview_window(origin_pane, vim.env.TMUX_PANE, true)
    else
      notify_error 'Leaf preview could not identify its originating pane'
    end
    return
  end

  if vim.fn.executable 'leaf' == 0 then
    notify_error 'Leaf preview could not find leaf on PATH'
    return
  end

  if vim.fn.executable 'nvim' == 0 then
    notify_error 'Leaf preview could not find nvim on PATH'
    return
  end

  local file_path = vim.api.nvim_buf_get_name(buffer)
  if file_path == '' then
    notify_error 'Leaf preview requires a file-backed Markdown buffer'
    return
  end

  local file = vim.uv.fs_stat(file_path)
  if not file or file.type ~= 'file' then
    notify_error 'Leaf preview requires the current file to exist on disk'
    return
  end

  local existing = get_existing_preview(vim.env.TMUX_PANE)
  if existing and existing.file == file_path then
    local _, select_error = run_tmux { 'tmux', 'select-window', '-t', existing.window }
    if select_error then
      notify_error('Could not select Leaf preview: ' .. select_error)
    end
    return
  end

  if existing and not close_preview_window(vim.env.TMUX_PANE, existing.window) then
    return
  end

  create_preview_window(vim.env.TMUX_PANE, file_path)
end

local function set_markdown_mappings(buffer)
  vim.keymap.set('n', '<leader>mt', '<cmd>RenderMarkdown toggle<cr>', {
    buffer = buffer,
    desc = 'Toggle Markdown rendering',
    silent = true,
  })
  vim.keymap.set('n', '<leader>ml', function()
    toggle_preview(buffer)
  end, {
    buffer = buffer,
    desc = 'Toggle Leaf preview window',
  })
end

function M.setup()
  local group = vim.api.nvim_create_augroup('markdown-mappings', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = 'markdown',
    callback = function(args)
      set_markdown_mappings(args.buf)
    end,
  })

  if vim.bo.filetype == 'markdown' then
    set_markdown_mappings(vim.api.nvim_get_current_buf())
  end
end

return M
