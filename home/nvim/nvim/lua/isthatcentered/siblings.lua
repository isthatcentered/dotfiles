local M = {}

local function alphabetical(left, right)
  local lower_left = vim.fn.tolower(left)
  local lower_right = vim.fn.tolower(right)

  if lower_left == lower_right then
    return left < right
  end

  return lower_left < lower_right
end

---@return boolean
function M.next_file()
  local path = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= '' or path == '' then
    return false
  end

  local directory = vim.fn.fnamemodify(path, ':h')
  local current_name = vim.fn.fnamemodify(path, ':t')
  local scan = vim.uv.fs_scandir(directory)
  if not scan then
    return false
  end

  local files = {}
  while true do
    local name = vim.uv.fs_scandir_next(scan)
    if not name then
      break
    end

    local stat = vim.uv.fs_stat(directory .. '/' .. name)
    if stat and stat.type == 'file' then
      files[#files + 1] = name
    end
  end

  if #files < 2 then
    return false
  end

  table.sort(files, alphabetical)
  for index, name in ipairs(files) do
    if name == current_name then
      local next_path = directory .. '/' .. files[index % #files + 1]
      vim.cmd('hide edit ' .. vim.fn.fnameescape(next_path))
      return true
    end
  end

  return false
end

vim.keymap.set('n', '<C-j>', M.next_file, { desc = 'Next sibling file' })

return M
