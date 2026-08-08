local STATUS = {
  ERROR = "ERROR",
  SUCCESS = "SUCCESS",
  PENDING = "PENDING",
}

---@alias DoneCallback fun(error?: unknown, value?: unknown)

---@class Promise
---@field value ?unknown
---@field error ?unknown
---@field status string
---@field finally_queue DoneCallback[]
local Promise = {}
Promise.__index = Promise

---@param fn fun(resolve: fun(value: unknown), reject: fun(error: unknown))
---@return Promise
function Promise.new(fn)
  local self = setmetatable({
    finally_queue = {},
    status = "PENDING",
  }, Promise)

  fn(
    function(value)
      self.value = value
      self.status = "SUCCESS"
      for _, callback in pairs(self.finally_queue) do
        callback(nil, value)
      end
    end, --
    function(error)
      self.error = error
      self.status = "ERROR"
      for _, callback in pairs(self.finally_queue) do
        callback(error, nil)
      end
    end
  )

  return self
end

function Promise.succeed(value)
  return Promise.new(function(res)
    res(value)
  end)
end

---@params on_done fun()
function Promise:finally(on_done)
  if self.status ~= STATUS.PENDING then
    on_done(self.error, nil)
    return self
  end

  table.insert(self.finally_queue, on_done)
  return self
end

---@param ffa fun(a:unknown): Promise
function Promise:flat_map(ffa) end

---@param f fun(a: unknown): unknown
function Promise:map(f) end

function Promise:unsafe_get_value()
  if self.status ~= "SUCCESS" then
    error("Promise not successful (Status: " .. self.status .. ")")
  end

  return self.value
end

function Promise:unsafe_get_error()
  if self.status ~= "ERROR" then
    error("Promise not successful (Status: " .. self.status .. ")")
  end

  return self.error
end

return Promise
