---@class Persistence
---@field path string
local M = {}
M.__index = M

---@param configuration {path: string}
function M.new(configuration)
  return setmetatable({ path = configuration.path }, M)
end

---@param registry Registry
function M:save(registry)
  local data = registry:serialize()
  local json = vim.json.encode(data)

  local file_path = self:_get_registry_path(registry.id)
  local result = vim.fn.writefile({ json }, file_path)
  if result ~= 0 then
    error("Failed to save data")
  end
end

---@param registry_id string
function M:load(registry_id)
  local file_path = self:_get_registry_path(registry_id)
  local success, lines = pcall(vim.fn.readfile, file_path)

  if not success or not lines[1] then
    return nil
  end

  return vim.json.decode(lines[1])
end

---@private
---@param registry_id string
function M:_get_registry_path(registry_id)
  return vim.fs.joinpath(self.path, registry_id .. ".json")
end

return M
