local MARKER = '// @TODO(REVIEW):'
local EMPTY_COMMENT_PLACEHOLDER = '<empty>'

local function insert_review_marker_above_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local current_line = vim.api.nvim_get_current_line()
  local indent = current_line:match '^%s*' or ''
  local todo_line = indent .. MARKER .. ' '

  vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { todo_line })
  vim.api.nvim_win_set_cursor(0, { row, #todo_line })
  vim.cmd 'startinsert'
end

local function open_review_picker()
  require('fzf-lua').grep {
    search = MARKER,
    cwd = vim.fn.getcwd(),
    prompt = 'Review TODOs> ',
  }
end

local function grep_review_to_quickfix()
  local cwd = vim.fn.getcwd()
  local lines = vim.fn.systemlist {
    'rg',
    '--vimgrep',
    '--no-heading',
    '--fixed-strings',
    '--glob',
    '!.git',
    MARKER,
    cwd,
  }
  local exit_code = vim.v.shell_error

  if exit_code > 1 then
    vim.notify('Review grep failed', vim.log.levels.ERROR)
    return
  end

  vim.fn.setqflist({}, ' ', {
    title = 'Review TODOs',
    lines = lines,
    efm = '%f:%l:%c:%m',
  })
  vim.cmd 'copen'
end

---@param line string
---@return { filepath: string, line_number: string, source_line: string }?
local function parse_review_vimgrep_line(line)
  local filepath, line_number, _, source_line = line:match '^(.+):(%d+):(%d+):(.*)$'

  if not filepath or not line_number or not source_line then
    return nil
  end

  return {
    filepath = filepath,
    line_number = line_number,
    source_line = source_line,
  }
end

---@param source_line string
---@return string?
local function extract_review_comment(source_line)
  local _, marker_end = source_line:find(MARKER, 1, true)
  if not marker_end then
    return nil
  end

  local comment = source_line:sub(marker_end + 1):gsub('^%s+', ''):gsub('%s+$', '')
  if comment == '' then
    return EMPTY_COMMENT_PLACEHOLDER
  end

  return comment
end

local function collect_review_todos_to_clipboard()
  local cwd = vim.fn.getcwd()
  local grep_lines = vim.fn.systemlist {
    'rg',
    '--vimgrep',
    '--no-heading',
    '--fixed-strings',
    '--glob',
    '!.git',
    MARKER,
    cwd,
  }
  local exit_code = vim.v.shell_error

  if exit_code > 1 then
    vim.notify('Review collect failed', vim.log.levels.ERROR)
    return
  end

  local collected_lines = {}
  for _, grep_line in ipairs(grep_lines) do
    local parsed = parse_review_vimgrep_line(grep_line)
    if parsed then
      local comment = extract_review_comment(parsed.source_line)
      if comment then
        table.insert(collected_lines, parsed.filepath .. '#L' .. parsed.line_number .. ': ' .. comment)
      end
    end
  end

  vim.fn.setreg('+', table.concat(collected_lines, '\n'))
  vim.notify('Copied ' .. #collected_lines .. ' review todos to clipboard')
end

vim.keymap.set('n', '<leader>R', insert_review_marker_above_cursor, { desc = 'Insert review TODO above current line' })
vim.keymap.set('n', '<leader>rr', open_review_picker, { desc = 'Search review TODOs in cwd' })
vim.keymap.set('n', '<leader>rq', grep_review_to_quickfix, { desc = 'Send review TODOs to quickfix' })
vim.keymap.set('n', '<leader>rc', collect_review_todos_to_clipboard, { desc = 'Collect review TODOs to clipboard' })
