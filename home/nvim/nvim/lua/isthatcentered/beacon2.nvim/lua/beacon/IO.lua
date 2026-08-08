local Exit = require("beacon.Exit")

---@class Async<E, A>
---@field fn fun(cb: fun(exit: Exit<any, any>))
---@field _tag "Async"
local Async = {}
Async.__index = Async

---@generic A
---@generic E
---@param fn fun(cb: fun(exit: Exit<E, A>))
function Async.new(fn)
  return setmetatable({
    fn = function(done)
      local ok, err = pcall(fn, done)
      if not ok then
        done(Exit.die(err))
      end
    end,
    _tag = "Async",
  }, Async)
end

---@class FlatMap<E, A>
---@field fa IO<any, any>
---@field ffb fun(a:any): IO<any, any>
---@field _tag "FlatMap"
local FlatMap = {}
FlatMap.__index = FlatMap

---@generic E, E2, A, B
---@param fa IO<E, A>
---@param ffb fun(a:A): IO<E | E2, B>
function FlatMap.new(fa, ffb)
  return setmetatable({
    fa = fa,
    ffb = ffb,
    _tag = "FlatMap",
  }, FlatMap)
end

---@alias _IO<E, A> Async<E,A> | FlatMap<E, A>

------------------------------
------- IO -------------------
------------------------------

---@class IO<E, A>
---@field fa _IO<any, any>
local IO = {}
IO.__index = IO

---@generic E, A, B
---@param ffb fun(a: A): IO<E, B>
function IO:flat_map(ffb)
  return IO.new(FlatMap.new(self.fa, ffb))
end

------------------------------
------- CONSTRUCTORS ---------
------------------------------
---@private
---@generic E
---@generic A
---@param io _IO<E, A>
---@return IO<E,A>
function IO.new(io)
  return setmetatable({
    fa = io,
  }, IO)
end

---@generic A
---@param value A
---@return IO<nil, A>
function IO.succeed(value)
  return IO.new(Async.new(function(done)
    done(Exit.succeed(value))
  end))
end

---@generic A
---@param failure A
---@return IO<A, nil>
function IO.fail(failure)
  return IO.new(Async.new(function(done)
    done(Exit.fail(failure))
  end))
end

---@param cause any
---@return IO<nil, any>
function IO.die(cause)
  return IO.new(Async.new(function(done)
    done(Exit.die(cause))
  end))
end

---@generic A
---@param fn fun(): A
---@return IO<nil, A>
function IO.sync(fn)
  return IO.new(Async.new(function(done)
    done(fn())
  end))
end

---@generic E
---@generic A
---@param fn fun(cb: fun(exit: Exit<E, A>))
---@return IO<E, A>
function IO.async(fn)
  return IO.new(Async.new(fn))
end

------------------------------
------- INTERPRETERS ---------
------------------------------

---@generic E
---@generic A
---@param io IO<E,A>
---@param on_done Exit<E, A>
function IO.run(io, on_done)
  ---@param io _IO<any, any>
  ---@param on_done fun(exit: Exit<any,any>)
  function loop(io, on_done)
    if io._tag == "Async" then
      io.fn(on_done)
    elseif io._tag == "FlatMap" then
      loop(io.fa, function(exit)
        if Exit.is_success(exit) then
          loop(io.ffb(exit.value).fa, on_done)
          return
        end
        on_done(exit)
      end)
    else
      error("Unhandled io type: " .. io._tag)
    end
  end

  loop(io.fa, on_done)
end

return IO
