local M = {}

local function notify_error(message)
  vim.notify(message, vim.log.levels.ERROR)
end

local function open_preview(buffer)
  if not vim.env.TMUX or vim.env.TMUX == '' or not vim.env.TMUX_PANE or vim.env.TMUX_PANE == '' then
    notify_error 'Leaf preview requires Neovim to be running inside tmux'
    return
  end

  if vim.fn.executable 'tmux' == 0 then
    notify_error 'Leaf preview could not find tmux on PATH'
    return
  end

  if vim.fn.executable 'leaf' == 0 then
    notify_error 'Leaf preview could not find leaf on PATH'
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

  local shell = vim.env.SHELL
  if not shell or shell == '' then
    shell = vim.o.shell
  end
  local pane_command = string.format('leaf --watch %s; exec %s -l', vim.fn.shellescape(file_path), vim.fn.shellescape(shell))
  local tmux_command = {
    'tmux',
    'split-window',
    '-h',
    '-p',
    '50',
    '-c',
    '#{pane_current_path}',
    '-t',
    vim.env.TMUX_PANE,
    pane_command,
  }

  local on_exit = vim.schedule_wrap(function(result)
    if result.code == 0 then
      return
    end

    local detail = vim.trim(result.stderr or '')
    notify_error(detail ~= '' and 'Could not open Leaf preview: ' .. detail or 'Could not open Leaf preview pane')
  end)

  local ok, error_message = pcall(vim.system, tmux_command, { text = true }, on_exit)
  if not ok then
    notify_error('Could not open Leaf preview: ' .. tostring(error_message))
  end
end

local function set_markdown_mappings(buffer)
  vim.keymap.set('n', '<leader>mt', '<cmd>RenderMarkdown toggle<cr>', {
    buffer = buffer,
    desc = 'Toggle Markdown rendering',
    silent = true,
  })
  vim.keymap.set('n', '<leader>ml', function()
    open_preview(buffer)
  end, {
    buffer = buffer,
    desc = 'Open current file in Leaf',
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
