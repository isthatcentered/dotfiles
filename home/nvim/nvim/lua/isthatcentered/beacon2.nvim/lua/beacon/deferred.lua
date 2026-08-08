local STATUS = {
  PENDING = "pending",
  DONE = "done"
}

local M = {}

---@alias Subscriber fun(value: any): nil

---@class Deferred
---@field subscribers Subscriber[]
---@field status string
---@dield value
function M:new()
  self.__index = self
  return setmetatable({
    subscribers={},
    status = STATUS.PENDING,
    value = nil
  }, self)
end

function M:succeed(value)
  self.status = STATUS.DONE
  self.value = value
  for _, subscriber in pairs(self.subscribers) do
    subscriber(value)
  end
end


return M
