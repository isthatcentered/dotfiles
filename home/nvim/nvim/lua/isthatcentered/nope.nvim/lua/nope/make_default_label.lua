---Generate default label from run configuration fields
---@param adapter string
---@param file_path string|nil
---@param directory_path string|nil
---@param configuration_path string|nil
---@param watch boolean
---@return string
local function make_default_label(adapter, file_path, directory_path, configuration_path, watch)
  local parts = { adapter }
  if file_path then
    parts[#parts + 1] = vim.fn.fnamemodify(file_path, ":t")
  elseif directory_path then
    parts[#parts + 1] = vim.fn.fnamemodify(directory_path, ":t") .. "/"
  else
    parts[#parts + 1] = "all"
  end
  if configuration_path then
    parts[#parts + 1] = vim.fn.fnamemodify(configuration_path, ":t")
  end
  if watch then
    parts[#parts + 1] = "watch"
  end
  return table.concat(parts, ":")
end

return make_default_label
