local Promise = require("beacon.Promise")
local async = require("beacon.async")

function _it(desc, fn) end
-- ---@type fun(name:string, fn: fun(): nil): nil
-- local function test(name, fn)
--   it(name, fn)
-- end
--
-- ---@type fun(name:string, fn: fun():nil):nil
-- function desc(name, fn) end
--
-- function assert_equals(expected, actual)
--   assert.same(expected, actual)
-- end
--
-- ---@alias Position { lnum: number, col: number, end_lnum: number, end_col: number}
-- --@type fun(): Position
-- local function makeRandomPosition()
--   local bufferLineCount = 3
--   local bufferColCount = 10
--   local startLine = math.random(0, bufferLineCount - 1)
--   local endLine = math.max(startLine, math.random(0, bufferLineCount - 1))
--   local startCol = math.random(0, bufferColCount - 2) -- always leave at least 1 char for the extmark
--   local endCol = math.max(startCol + 1, math.random(0, bufferColCount - 1))
--   return {
--     lnum = startLine,
--     col = startCol,
--     end_lnum = endLine,
--     end_col = endCol,
--   }
-- end
--
-- local function listExtmarks(bufferId)
--   local marksData = vim.api.nvim_buf_get_extmarks(
--     bufferId,
--     nope.namespace,
--     { 0, 0 },
--     { 1000, 1000 },
--     { details = true, hl_name = true }
--   )
--
--   ---@type {startCol: number, endCol:number, startRow: number, endRow: number, highlight: string}
--   local marks = {}
--   for _, data in pairs(marksData) do
--     local _, startRow, startCol, details = unpack(data)
--     table.insert(marks, {
--       startRow = startRow,
--       startCol = startCol,
--       endRow = details.end_row,
--       endCol = details.end_col,
--       highlight = details.hl_group,
--       priority = details.priority,
--     })
--   end
--   return marks
-- end
--
-- local function listHighlights(bufferId)
--   local highlights = vim.tbl_map(function(mark)
--     return mark.highlight
--   end, listExtmarks(bufferId))
--
--   table.sort(highlights)
--
--   return highlights
-- end
--
-- -- Runner ={}
-- --
-- -- function Runner:new()
-- -- 	self.__index = self
-- -- 	return setmetatable({}, self)
-- -- end
-- ---@alias GetRunnerState fun(): "idle"|"running"
-- ---@alias StartRunner fun(): nil
-- ---@alias StopRunner fun(): nil
-- ---@alias Runner {
-- ---		status: GetRunnerState,
-- ---		start: StartRunner,
-- ---		stopRunner: StopRunner,
-- --- }
--
-- ---@type fun(): Runner
-- function makeNullRunner()
--   local running = false
--   return {
--     status = function()
--       if running then
--         return "running"
--       end
--
--       return "idle"
--     end,
--     start = function()
--       running = true
--     end,
--     stop = function()
--       running = false
--     end,
--   }
-- end
--
-- desc("Nope", function()
--   desc("Starting the plugin", function()
--     before_each(function() end)
--
--     test("Starts the given job", function()
--       ---@type Runner
--       local runner = makeNullRunner()
--       nope.start(runner)
--     end)
--   end)
--
--   -- starting the plugin
--   -- stopping the plugin
--   -- test results
--   -- can run multiple runners at a time ??? might be a bad idea, hwo does toggle work then ?
--
--   local testDiagnosticsNamespace = vim.api.nvim_create_namespace("test_diagnostics_namespace")
--   local bufferId = 1
--   local NULL_OPTIONS = {
--     diagnostics = {
--       highlight = function(diagnostic)
--         return nil
--       end,
--     },
--   }
--
--   before_each(function()
--     -- If there is no text in the buffer the extmarks will be placed at 0,0
--     vim.api.nvim_buf_set_lines(bufferId, 0, 3, false, { "0123456789", "0123456789", "0123456789" })
--     -- vim.print(vim.api.nvim_buf_get_lines(bufferId, 0, vim.api.nvim_buf_line_count(0), false))
--     nope.detach()
--     vim.diagnostic.reset(nil, bufferId)
--   end)
--
--   -- Runs command
--   -- RUnning command creates new window
--   -- RUn fail notifies
--   -- Process can be stopped
--   -- Unexpected process exit notifies
--   -- Go to test on "click", pin ttest/test file
--   test("No highlight given only sets default plugin highlights", function()
--     nope.setup({
--       diagnostics = {
--         highlight = function()
--           return nil
--         end,
--       },
--     })
--     local diagnostic = makeDiagnostic(vim.diagnostic.severity.ERROR)
--
--     vim.diagnostic.set(testDiagnosticsNamespace, bufferId, { diagnostic })
--
--     assert.same(listHighlights(bufferId), true)
--     assert.same(listHighlights(bufferId), { "BeaconDiagnosticError" })
--   end)
-- end)

-- describe("Coroutines", function()
--   -- it("blah", function()
--   --   local co = coroutine.create(function(tag)
--   --     local next_tag = tag
--   --     for i = 1, 2 do
--   --       --                          I give you this
--   --       --                          v
--   --       -- You give me this
--   --       -- v
--   --       next_tag = coroutine.yield(i .. next_tag) -- returns the arguments passed to coroutine.resume
--   --     end
--   --
--   --     coroutine.yield("sup")
--   --   end)
--   --
--   --   vim.print(coroutine.resume(co, "a")) -- Returns hasNext, arguments passed to yield
--   --   vim.print(coroutine.resume(co, "b"))
--   --   vim.print(coroutine.resume(co, "c"))
--   -- end)
--
--   it("Producer vs consumer", function()
--     local function receive(producer)
--       local status, value = coroutine.resume(producer)
--       return value
--     end
--
--     local function send(value)
--       coroutine.yield(value)
--     end
--
--     local function filter(predicate, producer)
--       return coroutine.create(function()
--         while true do
--           local value = receive(producer)
--           while not predicate(value) do
--             value = receive(producer)
--           end
--           send(value)
--         end
--       end)
--     end
--
--     local producer = coroutine.create(function()
--       local i = 0
--       while true do
--         i = i + 1
--         send(i)
--       end
--     end)
--
--     local function consumer(producer)
--       local i = 0
--       while i < 5 do
--         i = i + 1
--         local value = receive(producer)
--         vim.print({ value = value })
--       end
--     end
--
--     local function isEven(value)
--       return value % 2 == 0
--     end
--
--     -- consumer(filter(isEven, producer))
--   end)
--
--   -- Utility to allow for async testing.
--   -- Run your code then release once done
--   local function makeLatch()
--     local should_release = false
--     local await = function()
--       local released = vim.wait(1000 * 10, function()
--         return should_release
--       end, 10)
--       if not released then
--         error("Latch was never released")
--       end
--     end
--     local release = function()
--       should_release = true
--     end
--
--     return { await = await, release = release }
--   end
--
--   -- it("Blah2", function()
--   --   local function concat(left, right, cb)
--   --     vim.defer_fn(function()
--   --       cb(left .. right)
--   --     end, 1000)
--   --   end
--   --   local function concat_co(left, right)
--   --     local co = coroutine.running()
--   --     concat(left, right, function(result)
--   --       vim.print("resume")
--   --       coroutine.resume(co, result)
--   --     end)
--   --     vim.print("yield")
--   --     return coroutine.yield()
--   --   end
--   --
--   --   coroutine.resume(coroutine.create(function()
--   --     local ab = concat_co("a", "b")
--   --     local abc = concat_co(ab,"c")
--   --     vim.print(abc)
--   --   end))
--   --
--   --   vim.wait(5000, function() return false end , 500)
--   -- end)
--   -- it("Running async stuff like it's synchronous", function()
--   --   local latch = makeLatch()
--   --   local co = coroutine.create(function()
--   --     local timer = assert(vim.uv.new_timer(), "vim.uv.new_timer not available")
--   --     timer:start(
--   --       1000,
--   --       0,
--   --       (function()
--   --         vim.print("co:::init")
--   --         coroutine.yield("resolved_value")
--   --         vim.print("co:::done")
--   --
--   --         latch.release()
--   --       end)
--   --     )
--   --   end)
--   --
--   --   vim.print(coroutine.resume(co))
--   --   vim.print("done")
--   --   coroutine.resume(co)
--   --   -- local timer = assert(vim.uv.new_timer(), "Timer not available")
--   --   -- timer:start(1000, 0, function()
--   --   --   latch.release()
--   --   -- end)
--   --   latch.await()
--   -- end)
--   it("Async as sync", function()
--     local latch = makeLatch()
--     local do_async_stuff = function()
--       local co = coroutine.running()
--       vim.defer_fn(function()
--         coroutine.resume(co, "return_value")
--       end, 5000)
--       return coroutine.yield() -- yield stops the coroutine. Once the coroutine is resumed, it returns what is passed to resume
--     end
--
--     coroutine.wrap(function()
--       local blah = do_async_stuff()
--       vim.print(blah)
--       latch.release()
--     end)()
--
--     latch:await()
--   end)
-- end)

---@param params {enabled: boolean}
---@return function
function make_logger(params)
  if params.enabled then
    return function(...)
      vim.print(...)
    end
  end
  return function() end
end

local function make_latch()
  local should_release = false
  local value = nil

  local await = function()
    local released = vim.wait(1000 * 10, function()
      return should_release
    end, 10)

    if not released then
      error("Latch was never released")
    end

    return value
  end

  local release = function(a)
    should_release = true
    value = a
  end

  return { await = await, release = release }
end

describe("Demistifying async in lua", function()
  it("Consumer/producer", function()
    local log = make_logger({ enabled = false })
    local producer = coroutine.create(function()
      local n = 0
      local nextMultiplier = 1
      while true do
        n = n + 1
        nextMultiplier = coroutine.yield(n * nextMultiplier) -- Here's what i made, do you have input for the next round?
      end
    end)

    local consumer = function(producer)
      return coroutine.create(function()
        local n = 1
        while n < 5 do
          n = n + 1
          local success, produced = coroutine.resume(producer, n) -- Go to work on this thing
          log(produced)
        end
      end)
    end

    coroutine.wrap(function()
      coroutine.resume(consumer(producer))
    end)()
  end)

  it("Communication using a shared table", function()
    local log = make_logger({ enabled = false })
    local queue = {}
    local sender = coroutine.create(function()
      table.insert(queue, "First message")
      coroutine.yield()
      table.insert(queue, "Second message")
      coroutine.yield()
      table.insert(queue, "Third message")
    end)

    local receiver = coroutine.create(function()
      while #queue > 0 do
        local message = table.remove(queue, 1)
        log(message)
        coroutine.yield()
        log("done")
      end
    end)

    coroutine.wrap(function()
      coroutine.resume(sender)
      coroutine.resume(receiver)
      coroutine.resume(sender)
      coroutine.resume(receiver)
      coroutine.resume(sender)
      coroutine.resume(receiver)
    end)()
  end)

  it("Looping communication using a shared table", function()
    local log = make_logger({ enabled = false })
    local queue = {}
    local sender = function(receiver)
      return coroutine.create(function()
        table.insert(queue, "First message")
        coroutine.resume(receiver)
        table.insert(queue, "Second message")
        coroutine.resume(receiver)
        table.insert(queue, "Third message")
        coroutine.resume(receiver)
      end)
    end

    local receiver = coroutine.create(function()
      while #queue > 0 do
        local message = table.remove(queue, 1)
        log(message)
        coroutine.yield()
      end
    end)

    coroutine.wrap(function()
      local loop = sender(receiver)
      coroutine.resume(loop)
      coroutine.resume(loop)
    end)()
  end)

  it("No scheduler", function()
    local log = make_logger({ enabled = false })
    local sleep = function(durationMs)
      local co = coroutine.running()
      vim.defer_fn(function()
        coroutine.resume(co, "sleep_done_value")
      end, durationMs)

      return coroutine.yield()
    end

    local latch = make_latch()
    coroutine.wrap(function()
      log("sleeping")
      local done_value = sleep(1000)
      log("slept", done_value)
      latch:release()
    end)()

    latch:await()
  end)

  describe("Scheduler", function()
    it("Schedules and resumes automatically", function()
      local latch = make_latch()
      local result

      async.run(
        function()
          local a = async.delayed("A", 100)
          local b = async.delayed("B", 100)
          local c = async.delayed("C", 100)

          return { a, b, c }
        end, --
        function(value)
          result = value
          latch:release()
        end
      )

      latch:await()
      assert.same({ "A", "B", "C" }, result)
    end)

    it("Error triggers failure handler", function()
      local latch = make_latch()
      local result

      async.run(
        function()
          async.suspend(function()
            error("suspend_error")
          end)
        end, --
        nil,
        function(error)
          result = error
          latch:release()
        end
      )

      latch:await()
      assert.is_number(string.find(result, "suspend_error"))
    end)
  end)

  ---@param fn fun(done): nil
  function suspend(fn)
    local co = coroutine.running()
    fn(function(value)
      coroutine.resume(co, value)
    end)

    coroutine.yield(co)
  end

  function delayed(value, delay)
    suspend(function(done)
      vim.print("running" .. value)
      vim.defer_fn(function()
        done(value)
        vim.print("done " .. value)
      end, delay)
    end)
  end
end)

describe("Promise", function()
  describe("finally", function()
    it("Promise resolving synchrounously", function()
      local latch = make_latch()

      Promise.new(function(res)
        res(nil)
      end):finally(function()
        latch:release()
      end)

      latch:await()
    end)

    it("Promise rejecting synchrounously", function()
      local latch = make_latch()

      Promise.new(function(_, rej)
        rej(nil)
      end):finally(function()
        latch:release()
      end)

      latch:await()
    end)

    it("Promise resolving asynchrounously", function()
      local latch = make_latch()

      Promise.new(function(res)
        vim.defer_fn(res, 10)
      end):finally(function()
        latch:release()
      end)

      latch:await()
    end)

    it("Promise rejecting asynchrounously", function()
      local latch = make_latch()

      Promise.new(function(_, rej)
        vim.defer_fn(rej, 10)
      end):finally(function()
        latch:release()
      end)

      latch:await()
    end)

    it("Callbacks are triggered in registration order", function()
      local latch = make_latch()
      local registered = {}

      Promise.new(function(_, rej)
        vim.defer_fn(rej, 10)
      end)
        :finally(function()
          table.insert(registered, "A")
        end)
        :finally(function()
          table.insert(registered, "B")
        end)
        :finally(function()
          table.insert(registered, "C")
        end)
        :finally(function()
          latch:release()
        end)

      latch:await()
      assert.same({ "A", "B", "C" }, registered)
    end)

    it("A")
    --@TODO: executes after then and catch
    --@TODO: only executes for the promise it was attached to
    --
  end)

  it("Resolve stores success value", function()
    local latch = make_latch()

    local promise = Promise.new(function(res)
      vim.defer_fn(function()
        res("value")
        latch:release()
      end, 10)
    end)

    latch:await()
    assert.same("value", promise:unsafe_get_value())
  end)

  -- it("then (promise success)", function()
  --   local latch = make_latch()
  --
  --   local promise = Promise.succeed(2):flat_map(function(n)
  --     latch:release()
  --     return Promise.succeed(n * 2)
  --   end)
  --
  --   latch:await()
  --   assert.same(4, promise:unsafe_get_value())
  -- end)
end)
