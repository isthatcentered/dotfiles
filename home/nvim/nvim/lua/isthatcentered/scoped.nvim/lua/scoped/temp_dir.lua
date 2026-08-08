local M = {}

local created = {}

-- Normalize slashes for Windows/Unix
local function join(a, b)
  if package.config:sub(1, 1) == "\\" then
    return a .. "\\" .. b
  else
    return a .. "/" .. b
  end
end

function M.create_dir()
  local dir_name = vim.fn.tempname()

  vim.fn.mkdir(dir_name, "p")

  table.insert(created, dir_name)

  return dir_name
end

function M.cleanup_all()
  for _, dir in ipairs(created) do
    if not string.find(dir, "nvim.eouardpenin") then
      -- Just in case
      return
    end

    vim.fn.delete(dir, "rf")
  end
  created = {}
end

return M
