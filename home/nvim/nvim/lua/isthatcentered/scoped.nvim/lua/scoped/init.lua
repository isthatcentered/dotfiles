local Scoped = require("scoped.Scoped")

local M = {}

local instance = nil
---@return Scoped
function M.instance()
  if not instance then
    instance = Scoped.new()
    return instance
  end

  return instance
end

return M
