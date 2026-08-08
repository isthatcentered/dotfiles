---@class RunConfigurationOpts
---@field configuration_path string|nil
---@field file_path string|nil
---@field directory_path string|nil
---@field watch boolean
---@field label string

---@class RunConfiguration
---@field adapter string
---@field configuration_path string|nil
---@field file_path string|nil
---@field directory_path string|nil
---@field watch boolean
---@field key string
---@field label string
local M = {}
M.__index = M

---@param adapter_name string
---@param opts RunConfigurationOpts
---@return RunConfiguration
function M.new(adapter_name, opts)
  if opts.file_path and opts.directory_path then
    error("Cannot specify both file_path and directory_path")
  end

  local key = vim.fn.sha256(
    adapter_name
      .. (opts.configuration_path or "")
      .. (opts.file_path or "")
      .. (opts.directory_path or "")
      .. tostring(opts.watch)
  )

  return setmetatable({
    adapter = adapter_name,
    configuration_path = opts.configuration_path,
    file_path = opts.file_path,
    directory_path = opts.directory_path,
    watch = opts.watch,
    key = key,
    label = opts.label,
  }, M)
end


return M
