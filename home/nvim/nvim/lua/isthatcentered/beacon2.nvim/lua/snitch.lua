local M = {}

local current_search = {
  matches = {},
  index = 1
}

function M.setup()
  vim.api.nvim_create_user_command('Snitch', M.search, { nargs = 0 })
  vim.api.nvim_set_keymap('n', 'n', ':lua require("snitch").next_match()<CR>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('n', 'N', ':lua require("snitch").previous_match()<CR>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('i', '<Esc>', '<Esc>:lua require("snitch").clear_matches()<CR>', { noremap = true, silent = true })

  vim.api.nvim_exec([[highlight SnitchMatch guibg=yellow guifg=black]], false)
  vim.api.nvim_exec([[autocmd TextChanged,TextChangedI * lua require("snitch").clear_matches()]], false)
end

function M.clear_matches()
  if current_search.match_id then
    vim.fn.matchdelete(current_search.match_id)
    current_search.match_id = nil
  end
end

function M.search()
  M.clear_matches()
  current_search.matches = {}
  current_search.index = 1

  local input = vim.fn.input('Enter 3 characters: ')
  if #input ~= 3 then
    print('Snitch requires exactly 3 characters.')
    return
  end

  local buffer = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)

  for i, line in ipairs(lines) do
    local start_col = 1
    while true do
      local match_start, match_end = string.find(line, input, start_col)
      if not match_start then
        break
      end
      table.insert(current_search.matches, { line = i, col = match_start, end_col = match_end })
      start_col = match_end + 1
    end
  end

  if #current_search.matches > 0 then
    M.jump_to_match(current_search.index)
    M.highlight_matches()
  else
    print('No matches found.')
  end
end

function M.highlight_matches()
  local positions = {}
  for _, match in ipairs(current_search.matches) do
    table.insert(positions, { match.line, match.col, match.end_col - match.col + 1 })
  end
  current_search.match_id = vim.fn.matchaddpos('SnitchMatch', positions)
end

function M.jump_to_match(index)
  if index < 1 or index > #current_search.matches then
    return
  end

  local match = current_search.matches[index]
  vim.api.nvim_win_set_cursor(0, { match.line, match.col - 1 })
  current_search.index = index
end

function M.next_match()
  if #current_search.matches == 0 then
    return
  end

  local next_index = current_search.index + 1
  if next_index > #current_search.matches then
    next_index = 1
  end
  M.jump_to_match(next_index)
end

function M.previous_match()
  if #current_search.matches == 0 then
    return
  end

  local prev_index = current_search.index - 1
  if prev_index < 1 then
    prev_index = #current_search.matches
  end
  M.jump_to_match(prev_index)
end

return M