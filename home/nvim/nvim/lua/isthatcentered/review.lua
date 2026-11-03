local M = {}
local namespace = vim.api.nvim_create_namespace 'isthatcentered.review'
local comments = {}
local quickfix_id

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = 'Agent feedback' })
end

local function set_highlights()
  vim.api.nvim_set_hl(0, 'AgentFeedback', { bg = vim.o.background == 'light' and '#f6e3b4' or '#493b23', default = true })
  vim.api.nvim_set_hl(0, 'AgentFeedbackSign', { fg = '#d79921', default = true })
end

local function get_range(comment)
  if not vim.api.nvim_buf_is_loaded(comment.buffer) then
    return nil
  end
  local mark = vim.api.nvim_buf_get_extmark_by_id(comment.buffer, namespace, comment.mark, { details = true })
  if #mark == 0 then
    return nil
  end
  local details = mark[3]
  return {
    start = { line = mark[1] + 1, column = mark[2] + 1 },
    finish = { line = details.end_row + 1, column = details.end_col + 1 },
    invalid = details.invalid or details.end_row < mark[1] or (details.end_row == mark[1] and details.end_col <= mark[2]),
  }
end

local function quickfix_items()
  local items = {}
  for _, comment in ipairs(comments) do
    local range = get_range(comment)
    if range then
      table.insert(items, {
        bufnr = comment.buffer,
        lnum = math.min(range.start.line, vim.api.nvim_buf_line_count(comment.buffer)),
        col = range.start.column,
        text = (range.invalid and '[deleted range: undo or <leader>rd to discard] ' or '') .. comment.text,
      })
    end
  end
  return items
end

local function refresh_quickfix()
  if quickfix_id and vim.fn.getqflist({ id = quickfix_id }).id == quickfix_id then
    vim.fn.setqflist({}, 'r', { id = quickfix_id, items = quickfix_items() })
    if #comments == 0 and vim.fn.getqflist({ id = 0 }).id == quickfix_id then
      vim.cmd 'cclose'
    end
  end
end

local function delete_mark(comment)
  if vim.api.nvim_buf_is_loaded(comment.buffer) then
    vim.api.nvim_buf_del_extmark(comment.buffer, namespace, comment.mark)
  end
end

local function selection_range(mode)
  if mode == 'n' then
    local line = vim.api.nvim_win_get_cursor(0)[1]
    return line - 1, 0, line, 0, 'line'
  end
  local region = vim.fn.getregionpos(vim.fn.getpos 'v', vim.fn.getpos '.', { type = mode, eol = true })
  local first, last = region[1][1], region[#region][2]
  if mode == 'V' then
    return first[2] - 1, 0, last[2], 0, 'line'
  end
  local last_line = vim.api.nvim_buf_get_lines(0, last[2] - 1, last[2], false)[1]
  if last[3] == 0 or last[3] > #last_line then
    return first[2] - 1, first[3] - 1, last[2], 0, 'character'
  end
  -- getregionpos includes the final UTF-8 byte, which is already the exclusive API offset.
  return first[2] - 1, first[3] - 1, last[2] - 1, last[3], 'character'
end

function M.add()
  local buffer = vim.api.nvim_get_current_buf()
  if vim.bo[buffer].buftype ~= '' or vim.api.nvim_buf_get_name(buffer) == '' then
    notify('Feedback needs a named file buffer.', vim.log.levels.WARN)
    return false
  end
  local mode = vim.fn.mode()
  if mode ~= 'n' and mode ~= 'v' and mode ~= 'V' then
    notify('Use v or V for feedback, not blockwise selection.', vim.log.levels.WARN)
    return false
  end
  local row, col, end_row, end_col, kind = selection_range(mode)
  local options = { end_row = end_row, end_col = end_col, right_gravity = true, end_right_gravity = false, invalidate = true }
  local comment = {
    buffer = buffer,
    mark = vim.api.nvim_buf_set_extmark(buffer, namespace, row, col, options),
    root = vim.fs.root(buffer, '.git') or vim.fn.getcwd(),
    kind = kind,
  }
  if mode ~= 'n' then
    vim.cmd.normal { args = { vim.keycode '<Esc>' }, bang = true }
  end
  local ok, err = pcall(vim.ui.input, { prompt = 'Feedback: ' }, function(input)
    if not input or vim.trim(input) == '' then
      delete_mark(comment)
      return
    end
    local range = get_range(comment)
    if not range or range.invalid then
      delete_mark(comment)
      notify('Selected text or buffer was deleted before feedback was saved.', vim.log.levels.WARN)
      return
    end
    comment.text = vim.trim(input)
    options.id = comment.mark
    options.end_row, options.end_col = range.finish.line - 1, range.finish.column - 1
    options.hl_group, options.hl_eol = 'AgentFeedback', true
    options.sign_text, options.sign_hl_group, options.priority = '!', 'AgentFeedbackSign', 200
    vim.api.nvim_buf_set_extmark(buffer, namespace, range.start.line - 1, range.start.column - 1, options)
    table.insert(comments, comment)
    refresh_quickfix()
    notify('Feedback saved in memory (' .. #comments .. ' pending).')
  end)
  if not ok then
    delete_mark(comment)
    notify('Could not open feedback input: ' .. tostring(err), vim.log.levels.ERROR)
  end
  return ok
end

function M.list()
  if #comments == 0 then
    notify 'No pending feedback.'
    return false
  end
  vim.fn.setqflist({}, ' ', { title = 'Agent feedback', items = quickfix_items() })
  quickfix_id = vim.fn.getqflist({ id = 0 }).id
  vim.cmd 'copen'
  return true
end

function M.remove()
  local buffer = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line, col = cursor[1], cursor[2] + 1
  local kept, count = {}, 0
  for _, comment in ipairs(comments) do
    local range = get_range(comment)
    local inside = range
      and (
        (range.invalid and line == math.min(range.start.line, vim.api.nvim_buf_line_count(comment.buffer)))
        or (
          (line > range.start.line or (line == range.start.line and col >= range.start.column))
          and (line < range.finish.line or (line == range.finish.line and col < range.finish.column))
        )
      )
    if comment.buffer == buffer and inside then
      delete_mark(comment)
      count = count + 1
    else
      table.insert(kept, comment)
    end
  end
  comments = kept
  refresh_quickfix()
  notify(count > 0 and ('Removed ' .. count .. ' feedback comment(s).') or 'No feedback under the cursor.')
  return count
end

local function copy_to_clipboard(json)
  if vim.g.clipboard == 'tmux' then
    -- The built-in provider queues this asynchronously and can report success even on failure.
    local result = vim.system({ 'tmux', 'load-buffer', '-w', '-' }, { stdin = json, text = true }):wait(5000)
    if result.code ~= 0 then
      error(vim.trim(result.stderr or '') ~= '' and result.stderr or 'tmux clipboard command failed')
    end
    return
  end
  if vim.fn.has 'clipboard' ~= 1 then
    error 'No clipboard provider is available (:checkhealth vim.provider).'
  end
  if vim.fn.setreg('+', json, 'v') ~= 0 then
    error 'Clipboard write failed.'
  end
  if vim.fn.getreg('+'):gsub('\r\n', '\n'):gsub('\n$', '') ~= json then
    error 'Clipboard readback did not match the export.'
  end
end

function M.collect()
  if #comments == 0 then
    notify 'No pending feedback; clipboard left unchanged.'
    return false
  end
  local entries, snapshot = {}, {}
  for _, comment in ipairs(comments) do
    local range = get_range(comment)
    if not range or range.invalid then
      notify('Feedback range was deleted. Use <leader>rr to locate it, then undo or <leader>rd to discard. Nothing copied.', vim.log.levels.WARN)
      return false
    end
    local name = vim.api.nvim_buf_get_name(comment.buffer)
    table.insert(entries, {
      file = vim.fs.relpath(comment.root, name) or name,
      project_root = comment.root,
      selection = comment.kind,
      start = range.start,
      ['end'] = range.finish,
      comment = comment.text,
    })
    snapshot[comment] = true
  end
  local json = vim.json.encode { version = 1, position_encoding = 'utf-8', range_convention = '1-based, end-exclusive', comments = entries }
  local ok, err = pcall(copy_to_clipboard, json)
  if not ok then
    notify('Copy failed; feedback kept: ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  local kept = {}
  for _, comment in ipairs(comments) do
    if snapshot[comment] then
      delete_mark(comment)
    else
      table.insert(kept, comment)
    end
  end
  comments = kept
  refresh_quickfix()
  notify('Copied ' .. #entries .. ' feedback comment(s) as JSON; exported feedback cleared.')
  return true
end

local group = vim.api.nvim_create_augroup('isthatcentered.review', { clear = true })
vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = set_highlights })
vim.api.nvim_create_autocmd('BufUnload', {
  group = group,
  callback = function(args)
    local kept, count = {}, 0
    for _, comment in ipairs(comments) do
      if comment.buffer == args.buf then
        count = count + 1
      else
        table.insert(kept, comment)
      end
    end
    comments = kept
    if count > 0 then
      vim.schedule(function()
        refresh_quickfix()
        notify('Buffer unloaded; discarded ' .. count .. ' feedback comment(s). Collect before deleting buffers.', vim.log.levels.WARN)
      end)
    end
  end,
})
set_highlights()
vim.keymap.set({ 'n', 'x' }, '<leader>R', M.add, { desc = 'Comment on selected code (in memory)' })
vim.keymap.set('n', '<leader>rr', M.list, { desc = 'List agent feedback' })
vim.keymap.set('n', '<leader>rq', M.list, { desc = 'Send agent feedback to quickfix' })
vim.keymap.set('n', '<leader>rc', M.collect, { desc = 'Copy feedback JSON and clear' })
vim.keymap.set('n', '<leader>rd', M.remove, { desc = 'Discard feedback under cursor' })

return M
