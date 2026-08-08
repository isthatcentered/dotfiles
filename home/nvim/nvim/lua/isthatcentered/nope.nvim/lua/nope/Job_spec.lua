local Job = require("nope.Job")
local spy = require("luassert.spy")

describe("Job", function()
  before_each(function() end)

  describe("start", function()
    it("Receives stdout", function()
      local co = coroutine.running()
      local stdout = {}
      local job = Job.new(
        { "echo", "stdout_value" },
        function(out)
          table.insert(stdout, out)
        end, --
        function() end,
        function()
          coroutine.resume(co)
        end
      )

      job:start()
      coroutine.yield()

      assert.same({ { "stdout_value" } }, stdout)
    end)

    it("Receives stderr", function()
      local co = coroutine.running()
      local stderr = {}
      local job = Job.new(
        { "sh", "-c", "echo stderr_value >&2" },
        function() end,
        function(out)
          table.insert(stderr, out)
        end, --
        function()
          coroutine.resume(co)
        end
      )

      job:start()
      coroutine.yield()

      assert.same({ { "stderr_value" } }, stderr)
    end)

    it("Receives exit code", function()
      local co = coroutine.running()
      local out_code = nil
      local job = Job.new(
        { "sh", "-c", ":;", "exit 1" },
        function() end,
        function(out) end, --
        function(code)
          out_code = code
          coroutine.resume(co)
        end
      )

      job:start()
      coroutine.yield()

      assert.same(0, out_code)
    end)

    it("Starting a job is idempotent", function()
      local co = coroutine.running()
      local events = {}
      local job = Job.new(
        { "echo", "stdout_value" },
        function(out)
          table.insert(events, "started")
        end, --
        function() end,
        function()
          table.insert(events, "stopped")
          coroutine.resume(co)
        end
      )

      job:start()
      job:start()
      job:start()
      job:start()
      coroutine.yield()

      assert.same({ "started", "stopped" }, events)
    end)
  end)

  describe("stop", function()
    it("No job started does nothing", function()
      local job = Job.new(
        { "sleep", "1000000" }, --
        function() end,
        function() end,
        function() end
      )

      job:stop()

      assert.Not.has_errors(function()
        job:stop()
      end)
    end)

    it("Stopping an already stopped job", function()
      local co = coroutine.running()
      local job = Job.new({ "sleep", "1000000" }, function() end, function() end, function()
        coroutine.resume(co)
      end)
      job:start()
      job:stop()
      coroutine.yield()

      assert.Not.has_errors(function()
        job:stop()
      end)
    end)

    it("Ends the running job", function()
      local co = coroutine.running()
      local exit_called = false
      local job = Job.new({ "sleep", "1000000" }, function() end, function() end, function()
        exit_called = true
        coroutine.resume(co)
      end)
      job:start()

      job:stop()

      coroutine.yield()
      assert.same(true, exit_called)
    end)
  end)
end)

---TODO: Add cwd support?
---TODO: What if the handler throws
---TODO: do you really need to expose pending?
