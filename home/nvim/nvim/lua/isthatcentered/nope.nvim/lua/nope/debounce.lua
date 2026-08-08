---Creates a debounced version of a function
---@param fn fun(...: any)
---@param delay_ms number
---@return fun(...: any) debounced, fun() cancel
local function debounce(fn, delay_ms)
  local timer = nil
  local pending_args = nil

  local function cancel()
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
    pending_args = nil
  end

  local function debounced(...)
    pending_args = { ... }
    if timer then
      timer:stop()
      timer:close()
    end
    timer = vim.uv.new_timer()
    timer:start(delay_ms, 0, vim.schedule_wrap(function()
      local args = pending_args
      cancel()
      if args then
        fn(unpack(args))
      end
    end))
  end

  return debounced, cancel
end

return debounce
