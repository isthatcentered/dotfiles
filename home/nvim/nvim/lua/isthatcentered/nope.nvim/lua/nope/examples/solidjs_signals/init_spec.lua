--------------------------------------------------------------------------------
-- Solid.js-style Reactive Signals - User Manual & Test Suite
--
-- This file serves as both a test suite and a user manual demonstrating
-- the usage patterns and behavior of the reactive primitives.
--
-- Table of Contents:
--   1. createSignal - Reactive state containers
--   2. createEffect - Reactive side effects
--   3. createMemo - Cached computed values
--   4. batch - Deferred updates
--   5. untrack - Escape hatch for dependency tracking
--   6. Advanced Patterns
--------------------------------------------------------------------------------

local reactive = require('nope.examples.solidjs_signals')
local createSignal = reactive.createSignal
local createEffect = reactive.createEffect
local createMemo = reactive.createMemo
local batch = reactive.batch
local untrack = reactive.untrack

describe('Solid.js-style Reactive Signals', function()
  --------------------------------------------------------------------------------
  -- 1. createSignal - Reactive State Containers
  --
  -- Signals are the atoms of reactivity. They hold a value and notify
  -- subscribers when that value changes.
  --
  -- Usage:
  --   local getter, setter = createSignal(initialValue)
  --   getter()        -- read current value
  --   setter(newVal)  -- update value and notify subscribers
  --------------------------------------------------------------------------------

  describe('createSignal - reactive state container', function()
    it('returns getter and setter functions', function()
      local count, setCount = createSignal(0)

      assert.same('function', type(count))
      assert.same('function', type(setCount))
    end)

    it('getter returns initial value', function()
      local count = createSignal(42)

      assert.same(42, count())
    end)

    it('getter returns updated value after setter called', function()
      local count, setCount = createSignal(0)

      setCount(10)

      assert.same(10, count())
    end)

    it('works with any value type', function()
      -- Numbers
      local num = createSignal(42)
      assert.same(42, num())

      -- Strings
      local str = createSignal('hello')
      assert.same('hello', str())

      -- Tables
      local tbl = createSignal({ a = 1, b = 2 })
      assert.same({ a = 1, b = 2 }, tbl())

      -- Booleans
      local bool = createSignal(true)
      assert.same(true, bool())

      -- nil
      local nilVal = createSignal(nil)
      assert.same(nil, nilVal())
    end)

    it('setter skips update if value unchanged (referential equality)', function()
      local effectRuns = 0
      local count, setCount = createSignal(5)

      createEffect(function()
        local _ = count()
        effectRuns = effectRuns + 1
      end)

      assert.same(1, effectRuns) -- initial run

      setCount(5) -- same value
      assert.same(1, effectRuns) -- no re-run

      setCount(10) -- different value
      assert.same(2, effectRuns) -- re-run
    end)
  end)

  --------------------------------------------------------------------------------
  -- 2. createEffect - Reactive Side Effects
  --
  -- Effects automatically track signal dependencies and re-run when those
  -- dependencies change. Perfect for side effects like logging, DOM updates,
  -- or API calls.
  --
  -- Usage:
  --   local dispose = createEffect(function()
  --     print("Count is: " .. count())  -- auto-tracks count
  --     return function() ... end       -- optional cleanup
  --   end)
  --   dispose()  -- stop the effect
  --------------------------------------------------------------------------------

  describe('createEffect - reactive side effects', function()
    it('runs immediately on creation', function()
      local runs = 0

      createEffect(function()
        runs = runs + 1
      end)

      assert.same(1, runs)
    end)

    it('auto-tracks signal dependencies', function()
      local count, setCount = createSignal(0)
      local observedValue

      createEffect(function()
        observedValue = count()
      end)

      assert.same(0, observedValue)

      setCount(42)
      assert.same(42, observedValue)
    end)

    it('tracks multiple dependencies', function()
      local firstName, setFirstName = createSignal('John')
      local lastName, setLastName = createSignal('Doe')
      local fullName

      createEffect(function()
        fullName = firstName() .. ' ' .. lastName()
      end)

      assert.same('John Doe', fullName)

      setFirstName('Jane')
      assert.same('Jane Doe', fullName)

      setLastName('Smith')
      assert.same('Jane Smith', fullName)
    end)

    it('re-runs only when dependencies change', function()
      local count, setCount = createSignal(0)
      local unrelated, setUnrelated = createSignal('foo')
      local runs = 0

      createEffect(function()
        local _ = count()
        runs = runs + 1
      end)

      assert.same(1, runs)

      setUnrelated('bar') -- not a dependency
      assert.same(1, runs)

      setCount(1)
      assert.same(2, runs)
    end)

    it('returns dispose function', function()
      local count, setCount = createSignal(0)
      local runs = 0

      local dispose = createEffect(function()
        local _ = count()
        runs = runs + 1
      end)

      assert.same(1, runs)

      dispose()

      setCount(10)
      assert.same(1, runs) -- no longer tracking
    end)

    it('supports cleanup function', function()
      local cleanupCalls = 0
      local count, setCount = createSignal(0)

      createEffect(function()
        local _ = count()
        return function()
          cleanupCalls = cleanupCalls + 1
        end
      end)

      assert.same(0, cleanupCalls)

      setCount(1) -- triggers re-run, cleanup called first
      assert.same(1, cleanupCalls)

      setCount(2)
      assert.same(2, cleanupCalls)
    end)

    it('cleanup runs on dispose', function()
      local cleanupCalls = 0

      local dispose = createEffect(function()
        return function()
          cleanupCalls = cleanupCalls + 1
        end
      end)

      assert.same(0, cleanupCalls)

      dispose()
      assert.same(1, cleanupCalls)
    end)

    it('handles conditional dependencies', function()
      -- Dependencies are re-tracked on each run
      local showDetails, setShowDetails = createSignal(false)
      local name, setName = createSignal('Alice')
      local age, setAge = createSignal(30)
      local runs = 0
      local result

      createEffect(function()
        runs = runs + 1
        if showDetails() then
          result = name() .. ' is ' .. age()
        else
          result = name()
        end
      end)

      assert.same(1, runs)
      assert.same('Alice', result)

      setAge(31) -- not a dependency yet
      assert.same(1, runs) -- no re-run

      setShowDetails(true)
      assert.same(2, runs)
      assert.same('Alice is 31', result)

      setAge(32) -- now a dependency
      assert.same(3, runs)
      assert.same('Alice is 32', result)
    end)

    it('handles nested effects correctly', function()
      local outer, setOuter = createSignal(0)
      local inner, setInner = createSignal(0)
      local outerRuns = 0
      local innerRuns = 0

      createEffect(function()
        local _ = outer()
        outerRuns = outerRuns + 1

        createEffect(function()
          local _ = inner()
          innerRuns = innerRuns + 1
        end)
      end)

      -- Initial: outer runs once, creates inner which runs once
      assert.same(1, outerRuns)
      assert.same(1, innerRuns)

      setInner(1)
      -- Inner effect re-runs
      assert.same(1, outerRuns)
      assert.same(2, innerRuns)
    end)
  end)

  --------------------------------------------------------------------------------
  -- 3. createMemo - Cached Computed Values
  --
  -- Memos compute derived state that automatically updates when dependencies
  -- change. Unlike effects, they cache and return a value.
  --
  -- Usage:
  --   local doubled = createMemo(function()
  --     return count() * 2
  --   end)
  --   doubled()  -- get cached value
  --------------------------------------------------------------------------------

  describe('createMemo - cached computed values', function()
    it('returns a getter function', function()
      local memo = createMemo(function()
        return 42
      end)

      assert.same('function', type(memo))
    end)

    it('computes value from dependencies', function()
      local count, setCount = createSignal(5)
      local doubled = createMemo(function()
        return count() * 2
      end)

      assert.same(10, doubled())

      setCount(10)
      assert.same(20, doubled())
    end)

    it('caches value - computation runs once per change', function()
      local computeCount = 0
      local count, setCount = createSignal(1)

      local doubled = createMemo(function()
        computeCount = computeCount + 1
        return count() * 2
      end)

      assert.same(1, computeCount) -- computed on creation

      doubled()
      doubled()
      doubled()
      assert.same(1, computeCount) -- cached, no recompute

      setCount(2)
      assert.same(1, computeCount) -- lazy: not recomputed until read

      doubled()
      assert.same(2, computeCount) -- recomputed on read

      doubled()
      doubled()
      assert.same(2, computeCount) -- cached again
    end)

    it('chains memos', function()
      local count, setCount = createSignal(2)

      local doubled = createMemo(function()
        return count() * 2
      end)

      local quadrupled = createMemo(function()
        return doubled() * 2
      end)

      assert.same(4, doubled())
      assert.same(8, quadrupled())

      setCount(3)
      assert.same(6, doubled())
      assert.same(12, quadrupled())
    end)

    it('can be used as effect dependency', function()
      local count, setCount = createSignal(1)
      local doubled = createMemo(function()
        return count() * 2
      end)

      local observedValue
      createEffect(function()
        observedValue = doubled()
      end)

      assert.same(2, observedValue)

      setCount(5)
      assert.same(10, observedValue)
    end)

    it('returns dispose function', function()
      local count, setCount = createSignal(1)
      local computeCount = 0

      local doubled, dispose = createMemo(function()
        computeCount = computeCount + 1
        return count() * 2
      end)

      assert.same(2, doubled())
      assert.same(1, computeCount)

      dispose()

      setCount(10)
      -- Memo is disposed, shouldn't recompute on dependency change
      -- Note: getter might still return last cached value
    end)

    it('handles complex derived state', function()
      local items, setItems = createSignal({ 1, 2, 3, 4, 5 })
      local filter, setFilter = createSignal('all')

      local filteredItems = createMemo(function()
        local list = items()
        local f = filter()
        if f == 'even' then
          local result = {}
          for _, v in ipairs(list) do
            if v % 2 == 0 then
              table.insert(result, v)
            end
          end
          return result
        elseif f == 'odd' then
          local result = {}
          for _, v in ipairs(list) do
            if v % 2 == 1 then
              table.insert(result, v)
            end
          end
          return result
        else
          return list
        end
      end)

      assert.same({ 1, 2, 3, 4, 5 }, filteredItems())

      setFilter('even')
      assert.same({ 2, 4 }, filteredItems())

      setFilter('odd')
      assert.same({ 1, 3, 5 }, filteredItems())

      setItems({ 10, 20, 30 })
      assert.same({}, filteredItems()) -- all even, but filter is 'odd'
    end)
  end)

  --------------------------------------------------------------------------------
  -- 4. batch - Deferred Updates
  --
  -- Batch multiple signal updates to run effects only once with the final
  -- state. Prevents "glitches" (intermediate inconsistent states).
  --
  -- Usage:
  --   batch(function()
  --     setFirstName("John")
  --     setLastName("Doe")
  --     -- effect runs ONCE here, after both updates
  --   end)
  --------------------------------------------------------------------------------

  describe('batch - deferred updates', function()
    it('defers effect execution until batch completes', function()
      local a, setA = createSignal(0)
      local b, setB = createSignal(0)
      local runs = 0
      local result

      createEffect(function()
        runs = runs + 1
        result = a() + b()
      end)

      assert.same(1, runs)
      assert.same(0, result)

      batch(function()
        setA(10)
        setB(20)
      end)

      -- Effect ran only once, not twice
      assert.same(2, runs)
      assert.same(30, result)
    end)

    it('prevents glitches (intermediate states)', function()
      local firstName, setFirstName = createSignal('John')
      local lastName, setLastName = createSignal('Doe')
      local observations = {}

      createEffect(function()
        table.insert(observations, firstName() .. ' ' .. lastName())
      end)

      assert.same({ 'John Doe' }, observations)

      -- Without batch, we might see "Jane Doe" then "Jane Smith"
      -- With batch, we only see final state
      batch(function()
        setFirstName('Jane')
        setLastName('Smith')
      end)

      assert.same({ 'John Doe', 'Jane Smith' }, observations)
    end)

    it('supports nested batches', function()
      local count, setCount = createSignal(0)
      local runs = 0

      createEffect(function()
        local _ = count()
        runs = runs + 1
      end)

      assert.same(1, runs)

      batch(function()
        setCount(1)
        batch(function()
          setCount(2)
          setCount(3)
        end)
        setCount(4)
      end)

      -- Only one effect run for all updates
      assert.same(2, runs)
    end)

    it('handles diamond dependency problem', function()
      -- Diamond:
      --        A
      --       / \
      --      B   C
      --       \ /
      --        D
      local a, setA = createSignal(1)
      local b = createMemo(function()
        return a() * 2
      end)
      local c = createMemo(function()
        return a() * 3
      end)
      local dRuns = 0
      local dValue

      createEffect(function()
        dRuns = dRuns + 1
        dValue = b() + c()
      end)

      assert.same(1, dRuns)
      assert.same(5, dValue) -- 2 + 3

      batch(function()
        setA(2)
      end)

      -- D should run only once, even though both B and C changed
      assert.same(2, dRuns)
      assert.same(10, dValue) -- 4 + 6
    end)

    it('batch returns nothing (void)', function()
      local result = batch(function()
        return 42
      end)

      assert.same(nil, result)
    end)
  end)

  --------------------------------------------------------------------------------
  -- 5. untrack - Escape Hatch
  --
  -- Read signals without creating dependencies. Useful when you need to
  -- access a value but don't want to re-run when it changes.
  --
  -- Usage:
  --   createEffect(function()
  --     local tracked = trackedSignal()
  --     local notTracked = untrack(function()
  --       return untrackedSignal()
  --     end)
  --   end)
  --------------------------------------------------------------------------------

  describe('untrack - escape hatch', function()
    it('reads signal without tracking', function()
      local tracked, setTracked = createSignal(0)
      local untracked, setUntracked = createSignal(0)
      local runs = 0
      local result

      createEffect(function()
        runs = runs + 1
        local t = tracked()
        local u = untrack(function()
          return untracked()
        end)
        result = t + u
      end)

      assert.same(1, runs)
      assert.same(0, result)

      setUntracked(10) -- not tracked, no re-run
      assert.same(1, runs)

      setTracked(5) -- tracked, re-run
      assert.same(2, runs)
      assert.same(15, result) -- includes updated untracked value
    end)

    it('works with nested untrack calls', function()
      local a = createSignal(1)
      local b = createSignal(2)
      local runs = 0

      createEffect(function()
        runs = runs + 1
        untrack(function()
          local _ = a()
          untrack(function()
            local _ = b()
          end)
        end)
      end)

      assert.same(1, runs)
    end)

    it('returns value from function', function()
      local count = createSignal(42)

      local value = untrack(function()
        return count()
      end)

      assert.same(42, value)
    end)
  end)

  --------------------------------------------------------------------------------
  -- 6. Advanced Patterns
  --------------------------------------------------------------------------------

  describe('Advanced patterns', function()
    it('counter example - classic reactive pattern', function()
      local count, setCount = createSignal(0)
      local history = {}

      createEffect(function()
        table.insert(history, count())
      end)

      setCount(1)
      setCount(2)
      setCount(3)

      assert.same({ 0, 1, 2, 3 }, history)
    end)

    it('derived state - computed from multiple signals', function()
      local price, setPrice = createSignal(100)
      local quantity, setQuantity = createSignal(2)
      local taxRate, setTaxRate = createSignal(0.1)

      local subtotal = createMemo(function()
        return price() * quantity()
      end)

      local tax = createMemo(function()
        return subtotal() * taxRate()
      end)

      local total = createMemo(function()
        return subtotal() + tax()
      end)

      assert.same(200, subtotal())
      assert.same(20, tax())
      assert.same(220, total())

      setQuantity(3)
      assert.same(300, subtotal())
      assert.same(30, tax())
      assert.same(330, total())
    end)

    it('form validation pattern', function()
      local email, setEmail = createSignal('')
      local password, setPassword = createSignal('')

      local emailValid = createMemo(function()
        return email():match('@') ~= nil
      end)

      local passwordValid = createMemo(function()
        return #password() >= 8
      end)

      local formValid = createMemo(function()
        return emailValid() and passwordValid()
      end)

      assert.same(false, formValid())

      setEmail('test@example.com')
      assert.same(false, formValid())

      setPassword('12345678')
      assert.same(true, formValid())
    end)

    it('effect with resource cleanup simulation', function()
      local subscriptions = {}
      local userId, setUserId = createSignal(1)

      local dispose = createEffect(function()
        local id = userId()
        -- Simulate subscribing to a resource
        table.insert(subscriptions, 'subscribe:' .. id)

        return function()
          -- Cleanup: unsubscribe when userId changes or effect disposed
          table.insert(subscriptions, 'unsubscribe:' .. id)
        end
      end)

      assert.same({ 'subscribe:1' }, subscriptions)

      setUserId(2)
      assert.same({
        'subscribe:1',
        'unsubscribe:1',
        'subscribe:2',
      }, subscriptions)

      dispose()
      assert.same({
        'subscribe:1',
        'unsubscribe:1',
        'subscribe:2',
        'unsubscribe:2',
      }, subscriptions)
    end)

    it('todo list example - complex state management', function()
      local nextId = 1
      local todos, setTodos = createSignal({})
      local filter, setFilter = createSignal('all') -- all, active, completed

      local filteredTodos = createMemo(function()
        local list = todos()
        local f = filter()
        if f == 'active' then
          local result = {}
          for _, todo in ipairs(list) do
            if not todo.completed then
              table.insert(result, todo)
            end
          end
          return result
        elseif f == 'completed' then
          local result = {}
          for _, todo in ipairs(list) do
            if todo.completed then
              table.insert(result, todo)
            end
          end
          return result
        else
          return list
        end
      end)

      local activeCount = createMemo(function()
        local count = 0
        for _, todo in ipairs(todos()) do
          if not todo.completed then
            count = count + 1
          end
        end
        return count
      end)

      -- Add todos
      local function addTodo(text)
        local current = todos()
        local newTodos = {}
        for _, t in ipairs(current) do
          table.insert(newTodos, t)
        end
        table.insert(newTodos, { id = nextId, text = text, completed = false })
        nextId = nextId + 1
        setTodos(newTodos)
      end

      -- Toggle todo
      local function toggleTodo(id)
        local current = todos()
        local newTodos = {}
        for _, t in ipairs(current) do
          if t.id == id then
            table.insert(newTodos, { id = t.id, text = t.text, completed = not t.completed })
          else
            table.insert(newTodos, t)
          end
        end
        setTodos(newTodos)
      end

      addTodo('Learn Lua')
      addTodo('Build reactive system')
      addTodo('Write tests')

      assert.same(3, #filteredTodos())
      assert.same(3, activeCount())

      toggleTodo(1)
      assert.same(2, activeCount())

      setFilter('completed')
      assert.same(1, #filteredTodos())

      setFilter('active')
      assert.same(2, #filteredTodos())
    end)
  end)
end)
