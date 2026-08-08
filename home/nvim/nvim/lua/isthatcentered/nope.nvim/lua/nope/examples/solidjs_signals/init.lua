--------------------------------------------------------------------------------
-- Solid.js-style Reactive Signals for Lua
--
-- A fine-grained reactivity system inspired by Solid.js. Provides automatic
-- dependency tracking and efficient updates through batching.
--
-- Core primitives:
--   - createSignal(value) -> getter, setter
--   - createEffect(fn) -> dispose
--   - createMemo(fn) -> getter, dispose
--   - batch(fn) -> defers effect execution until fn completes
--
-- Example:
--   local count, setCount = createSignal(0)
--   createEffect(function()
--     print("Count is: " .. count())
--   end)
--   setCount(1)  -- effect re-runs automatically
--------------------------------------------------------------------------------

local M = {}

--------------------------------------------------------------------------------
-- INTERNAL STATE
--------------------------------------------------------------------------------

---@class SolidSignal
---@field value any
---@field subscribers table<SolidSubscriber, boolean>

---@class SolidSubscriber
---@field dependencies table<SolidSignal, boolean>
---@field cleanup? fun()
---@field disposed boolean
---@field execute fun(self: SolidSubscriber)
---@field subscribers? table<SolidSubscriber, boolean>

-- Stack of currently executing computations (effects/memos)
-- When a signal is read, it registers as a dependency of the top computation
---@type SolidSubscriber[]
local tracking_stack = {}

-- Batching state
-- When batch_depth > 0, effects are queued instead of executed immediately
local batch_depth = 0

-- Flag to track if we're currently flushing effects
-- During flush, new effects should be queued, not run immediately
local is_flushing = false

-- Set of effects pending execution (during batching)
---@type table<SolidSubscriber, boolean>
local pending_effects = {}

--------------------------------------------------------------------------------
-- BATCHING
--
-- THEORY: Why batch updates?
--
-- Without batching, each signal update immediately triggers all dependent
-- effects. This causes problems:
--
-- 1. PERFORMANCE: Multiple updates = multiple effect runs
--      setFirstName("John")  -- effect runs (shows "John undefined")
--      setLastName("Doe")    -- effect runs again (shows "John Doe")
--    With batching: effect runs once with final state
--
-- 2. GLITCHES: Intermediate inconsistent states become visible
--      Imagine: fullName = firstName + " " + lastName
--      Without batching, an effect reading fullName might see "John undefined"
--      before lastName is set. This is called a "glitch".
--
-- 3. DIAMOND PROBLEM: In a dependency graph like:
--           A
--          / \
--         B   C
--          \ /
--           D
--    When A changes, D could run twice (once for B, once for C).
--    Batching ensures D runs once with both B and C updated.
--
-- HOW IT WORKS:
--   - batch() increments batch_depth
--   - Signal setters add effects to pending_effects instead of running them
--   - When batch_depth returns to 0, all pending effects run once
--   - Effects are deduplicated (same effect only runs once per batch)
--------------------------------------------------------------------------------

---Execute all pending effects (called when batch completes)
local function flush_effects()
  is_flushing = true

  -- Keep flushing until no more pending effects
  -- This handles cascading updates (e.g., memo -> effect chains)
  while next(pending_effects) do
    -- Copy pending set to avoid mutation during iteration
    local to_run = {}
    for effect in pairs(pending_effects) do
      table.insert(to_run, effect)
    end
    pending_effects = {}

    -- Execute each effect
    -- Note: these executions may schedule more effects (via memos notifying
    -- their subscribers). Those go to pending_effects and are handled in
    -- the next iteration, ensuring deduplication.
    for _, effect in ipairs(to_run) do
      effect:execute()
    end
  end

  is_flushing = false
end

---Schedule an effect for execution
---If not batching or flushing, runs immediately. Otherwise queues for later.
---@param effect SolidSubscriber
local function schedule_effect(effect)
  if batch_depth > 0 or is_flushing then
    pending_effects[effect] = true
  else
    effect:execute()
  end
end

---Batch multiple signal updates into a single effect execution
---Effects are deferred until the batch completes.
---Batches can be nested - effects only flush when outermost batch completes.
---@param fn fun()
function M.batch(fn)
  batch_depth = batch_depth + 1
  local ok, err = pcall(fn)
  batch_depth = batch_depth - 1

  if batch_depth == 0 then
    flush_effects()
  end

  if not ok then
    error(err)
  end
end

--------------------------------------------------------------------------------
-- DEPENDENCY TRACKING
--
-- THEORY: Automatic dependency tracking
--
-- The magic of reactive systems is that you don't manually specify dependencies.
-- Instead, dependencies are tracked automatically at runtime.
--
-- HOW IT WORKS:
--   1. Before running an effect, push it onto tracking_stack
--   2. When a signal's getter is called, check if tracking_stack is non-empty
--   3. If so, register the current computation as a subscriber
--   4. After effect completes, pop from tracking_stack
--
-- This means:
--   createEffect(function()
--     print(firstName() .. " " .. lastName())
--   end)
--
-- Automatically tracks firstName AND lastName as dependencies, because both
-- getters were called during the effect's execution.
--
-- CONDITIONAL DEPENDENCIES:
--   createEffect(function()
--     if showFullName() then
--       print(firstName() .. " " .. lastName())
--     else
--       print(firstName())
--     end
--   end)
--
-- Dependencies are re-tracked on each run. If showFullName() returns false,
-- lastName won't be read, so it won't be a dependency until showFullName
-- becomes true.
--------------------------------------------------------------------------------

---Get the currently tracking computation (if any)
---@return SolidSubscriber?
local function get_current_tracking()
  return tracking_stack[#tracking_stack]
end

---Push a computation onto the tracking stack
---@param subscriber SolidSubscriber
local function push_tracking(subscriber)
  table.insert(tracking_stack, subscriber)
end

---Pop a computation from the tracking stack
local function pop_tracking()
  table.remove(tracking_stack)
end

--------------------------------------------------------------------------------
-- createSignal
--
-- Creates a reactive state container. Returns a getter and setter pair.
-- - getter(): returns current value, registers dependency if inside effect/memo
-- - setter(value): updates value, notifies all subscribers
--
-- Signals are the atoms of reactivity - the primitive state containers that
-- everything else derives from.
--------------------------------------------------------------------------------

---Create a reactive signal (state container)
---@generic T
---@param initial_value T
---@return fun(): T getter
---@return fun(value: T) setter
function M.createSignal(initial_value)
  ---@type SolidSignal
  local signal = {
    value = initial_value,
    subscribers = {},
  }

  ---Get current value, registering dependency if tracking
  ---@return any
  local function getter()
    local current = get_current_tracking()
    if current then
      -- Register bidirectional relationship
      signal.subscribers[current] = true
      current.dependencies[signal] = true
    end
    return signal.value
  end

  ---Set new value, notifying subscribers if changed
  ---@param new_value any
  local function setter(new_value)
    -- Skip if value unchanged (referential equality)
    if signal.value == new_value then
      return
    end

    signal.value = new_value

    -- Schedule all subscribers for execution
    for subscriber in pairs(signal.subscribers) do
      schedule_effect(subscriber)
    end
  end

  return getter, setter
end

--------------------------------------------------------------------------------
-- createEffect
--
-- Creates a reactive side effect that automatically tracks dependencies and
-- re-runs when they change.
--
-- LIFECYCLE:
--   1. Effect runs immediately on creation
--   2. During execution, signal reads are tracked as dependencies
--   3. When any dependency changes, effect is scheduled for re-execution
--   4. Before each re-run, previous cleanup (if any) is called
--   5. When disposed, cleanup runs and effect stops tracking
--
-- CLEANUP:
--   If the effect function returns a function, it's treated as a cleanup
--   callback. Cleanup runs:
--   - Before each re-execution (to clean up previous run)
--   - When the effect is disposed
--
-- Example:
--   local dispose = createEffect(function()
--     local id = setInterval(function() ... end, 1000)
--     return function() clearInterval(id) end  -- cleanup
--   end)
--   dispose()  -- stops the effect and clears interval
--------------------------------------------------------------------------------

---Create a reactive effect that auto-tracks dependencies
---@param fn fun(): fun()?  Effect function, optionally returns cleanup
---@return fun() dispose  Call to stop the effect
function M.createEffect(fn)
  local effect = {
    dependencies = {},
    cleanup = nil,
    disposed = false,
  }

  ---Execute the effect, tracking dependencies
  function effect:execute()
    if self.disposed then
      return
    end

    -- Run cleanup from previous execution
    if self.cleanup then
      self.cleanup()
      self.cleanup = nil
    end

    -- Clear old dependencies (will re-track during execution)
    for signal in pairs(self.dependencies) do
      signal.subscribers[self] = nil
    end
    self.dependencies = {}

    -- Execute with tracking
    push_tracking(self)
    local ok, result = pcall(fn)
    pop_tracking()

    if not ok then
      error(result)
    end

    -- Store cleanup if returned
    if type(result) == 'function' then
      self.cleanup = result
    end
  end

  ---Dispose the effect (stop tracking, run cleanup)
  local function dispose()
    if effect.disposed then
      return
    end
    effect.disposed = true

    -- Run cleanup
    if effect.cleanup then
      effect.cleanup()
      effect.cleanup = nil
    end

    -- Remove from all signals' subscriber lists
    for signal in pairs(effect.dependencies) do
      signal.subscribers[effect] = nil
    end
    effect.dependencies = {}

    -- Remove from pending if batched
    pending_effects[effect] = nil
  end

  -- Run immediately
  effect:execute()

  return dispose
end

--------------------------------------------------------------------------------
-- createMemo
--
-- Creates a cached computation that automatically tracks dependencies and
-- recomputes when they change. Returns a getter function.
--
-- Memos are like effects, but:
--   - They return and cache a value
--   - They're lazy: only recompute when read (not immediately on change)
--   - They can be used as dependencies by other effects/memos
--
-- LAZY VS EAGER:
--   Solid.js memos are eager (recompute immediately when deps change).
--   This implementation is LAZY (marks dirty, recomputes on next read).
--   Lazy is simpler and avoids unnecessary computation if value isn't read.
--
-- Example:
--   local count, setCount = createSignal(1)
--   local doubled = createMemo(function()
--     return count() * 2
--   end)
--   print(doubled())  -- 2
--   setCount(5)
--   print(doubled())  -- 10
--------------------------------------------------------------------------------

---Create a memoized computation
---@generic T
---@param fn fun(): T  Computation function
---@return fun(): T getter  Returns cached value, recomputing if dirty
---@return fun() dispose  Call to stop the memo
function M.createMemo(fn)
  local memo = {
    dependencies = {},
    cleanup = nil,
    disposed = false,
    value = nil,
    dirty = true, -- Start dirty to compute on first read
    subscribers = {}, -- Effects/memos that depend on this memo
  }

  ---Mark memo as needing recomputation
  function memo:execute()
    if self.disposed then
      return
    end
    self.dirty = true

    -- Notify subscribers that depend on this memo
    if self.subscribers then
      for subscriber in pairs(self.subscribers) do
        schedule_effect(subscriber)
      end
    end
  end

  ---Recompute the cached value
  function memo:recompute()
    if self.disposed then
      return
    end

    -- Run cleanup from previous computation
    if self.cleanup then
      self.cleanup()
      self.cleanup = nil
    end

    -- Clear old dependencies
    for signal in pairs(self.dependencies) do
      signal.subscribers[self] = nil
    end
    self.dependencies = {}

    -- Execute with tracking
    push_tracking(self)
    local ok, result = pcall(fn)
    pop_tracking()

    if not ok then
      error(result)
    end

    self.value = result
    self.dirty = false
  end

  ---Get the cached value, recomputing if dirty
  local function getter()
    -- Recompute if dirty
    if memo.dirty then
      memo:recompute()
    end

    -- If read during tracking, register as dependency
    local current = get_current_tracking()
    if current then
      memo.subscribers[current] = true
      current.dependencies[memo] = true
    end

    return memo.value
  end

  ---Dispose the memo
  local function dispose()
    if memo.disposed then
      return
    end
    memo.disposed = true

    -- Run cleanup
    if memo.cleanup then
      memo.cleanup()
      memo.cleanup = nil
    end

    -- Remove from all signals' subscriber lists
    for signal in pairs(memo.dependencies) do
      signal.subscribers[memo] = nil
    end
    memo.dependencies = {}

    -- Remove from pending if batched
    pending_effects[memo] = nil
  end

  -- Initial computation
  memo:recompute()

  return getter, dispose
end

--------------------------------------------------------------------------------
-- untrack
--
-- Execute a function without tracking dependencies.
-- Useful when you need to read a signal inside an effect without subscribing.
--
-- Example:
--   createEffect(function()
--     local a = trackedSignal()  -- tracked
--     local b = untrack(function()
--       return untrackedSignal()  -- NOT tracked
--     end)
--   end)
--------------------------------------------------------------------------------

---Execute function without tracking dependencies
---@generic T
---@param fn fun(): T
---@return T
function M.untrack(fn)
  -- Save and clear tracking stack
  local saved_stack = tracking_stack
  tracking_stack = {}

  local ok, result = pcall(fn)

  tracking_stack = saved_stack

  if not ok then
    error(result)
  end

  return result
end

return M
