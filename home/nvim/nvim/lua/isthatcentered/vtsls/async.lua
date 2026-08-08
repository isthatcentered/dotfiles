local M = {}

function M.exec(func, res, rej)
  local co = coroutine.create(func)
  local step
  step = function(...)
    local args = { ... }
    local ok, nxt = coroutine.resume(co, unpack(args))

    -- Coroutine not complete
    if coroutine.status(co) ~= 'dead' then
      local _, err = xpcall(nxt, debug.traceback, step)
      if err then
        rej(err)
      end

    -- Coroutine is done
    elseif ok then
      res(unpack(args))

      -- Coroutine failed
    else
      rej(debug.traceback(co, nxt))
    end
  end

  step()
end

function M.call(func, ...)
  local n = select('#', ...)
  local args = { ... }
  return coroutine.yield(function(cb)
    args[n + 1] = cb
    func(unpack(args))
  end)
end

function M.async_call_err(func, ...)
  local n = select('#', ...)
  local args = { ... }
  return coroutine.yield(function(cb)
    args[n + 1] = cb
    args[n + 2] = function(e)
      error(e)
    end
    func(unpack(args))
  end)
end

function M.schedule()
  return coroutine.yield(function(cb)
    vim.schedule(cb)
  end)
end

function M.request(client, method, params, bufnr)
  return coroutine.yield(function(cb)
    client:request(method, params, cb, bufnr)
  end)
end

return M
