---@class Exit<E, A>
---@field _tag   "Succeed" | "Failure" | "Cause"
---@field failure unknown
---@field value unknown
---@field cause unknown
local Exit = {}
Exit.__index = Exit

---@return boolean
function Exit:is_success()
  return self._tag == "Succeed"
end

---@generic A
---@param value A
---@return Exit<nil, A>
function Exit.succeed(value)
  local self = setmetatable({ _tag = "Succeed", value = value }, Exit)
  return self
end

---@generic E
---@param failure E
---@return Exit<E, nil>
function Exit.fail(failure)
  local self = setmetatable({ _tag = "Failure", failure = failure }, Exit)
  return self
end

---@param cause any
---@return Exit<nil, nil>
function Exit.die(cause)
  local self = setmetatable({ _tag = "Die", cause = cause }, Exit)
  return self
end

return Exit
