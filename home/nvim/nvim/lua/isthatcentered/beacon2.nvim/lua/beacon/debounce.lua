---@param fn fun(...:any):any
---@param delay integer
---@return function
local function debounce(fn, delay)
  local timer_id = nil

  return function(...)
    local args = { ... }

    -- cancel previous timer if exists
    if timer_id then
      vim.fn.timer_stop(timer_id)
    end

    -- start a new timer
    timer_id = vim.fn.timer_start(delay, function()
      fn(unpack(args))
      timer_id = nil
    end)
  end
end

return debounce
