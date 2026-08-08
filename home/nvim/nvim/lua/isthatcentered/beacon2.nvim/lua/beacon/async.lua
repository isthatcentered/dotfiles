local M = {}

function M.run(fn, onDone, onFailure)
  local co = coroutine.create(fn)
  local loop
  loop = function(value)
    local succeeded, nextFnOrFinalResult = coroutine.resume(co, value)

    if coroutine.status(co) ~= "dead" then
      local ok, err = xpcall(nextFnOrFinalResult, debug.traceback, loop)

      if not ok then
        onFailure(err)
      end

    elseif succeeded then
      onDone(nextFnOrFinalResult) -- When the coroutine is done resume will return the return value of the coroutine

    else
      onFailure(debug.traceback(co, nextFnOrFinalResult))
    end
  end

  loop(nil)
end

---@param fn fun(cb: fun(value: any): nil): boolean, any
function M.suspend(fn)
  return coroutine.yield(fn)
end

function M.delayed(value, durationMs)
  return M.suspend(function(done)
    vim.defer_fn(function()
      done(value)
    end, durationMs)
  end)
end

return M
