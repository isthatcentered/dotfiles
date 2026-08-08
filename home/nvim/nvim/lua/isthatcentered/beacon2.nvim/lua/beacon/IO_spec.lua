local IO = require("beacon.IO")
local Exit = require("beacon.Exit")

local function make_latch()
  local should_release = false
  local value = nil

  local await = function()
    local released = vim.wait(1000 * 5, function()
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

function run_blocking(io)
  local result
  local latch = make_latch()

  IO.run(io, function(exit)
    result = exit
    latch:release()
  end)

  latch:await()
  return result
end

describe("IO", function()
  it("succeed", function()
    local result = run_blocking(IO.succeed("value"))

    assert.same(Exit.succeed("value"), result)
  end)

  it("fail", function()
    local result = run_blocking(IO.fail("value"))

    assert.same(Exit.fail("value"), result)
  end)

  describe("async", function()
    it("Success", function()
      local result = run_blocking(IO.async(function(done)
        vim.defer_fn(function()
          done(Exit.succeed("value"))
        end, 10)
      end))

      assert.same(Exit.succeed("value"), result)
    end)

    it("Failure", function()
      local result = run_blocking(IO.async(function(done)
        vim.defer_fn(function()
          done(Exit.fail("value"))
        end, 10)
      end))

      assert.same(Exit.fail("value"), result)
    end)

    it("Die", function()
      local result = run_blocking(IO.async(function(done)
        vim.defer_fn(function()
          done(Exit.die("value"))
        end, 10)
      end))

      assert.same(Exit.die("value"), result)
    end)

    it("Unexpected synchronous error", function()
      local result = run_blocking(IO.async(function()
        error("unexpected_error")
      end))

      assert.truthy(string.find(result.cause, "unexpected_error"))
    end)
  end)

  describe("flatMap", function()
    it("Failing IO is ignored", function()
      local result = run_blocking(IO.fail("whatever"):flat_map(function()
        error("Should not have been calle")
      end))

      assert.same(Exit.fail("whatever"), result)
    end)

    it("Dying IO is ignored", function()
      local result = run_blocking(IO.die("whatever"):flat_map(function()
        error("Should not have been calle")
      end))

      assert.same(Exit.die("whatever"), result)
    end)

    it("Suceeding IO runs", function()
      local result = run_blocking(IO.succeed(2):flat_map(function(value)
        return IO.succeed(value * 2)
      end))

      assert.same(Exit.succeed(4), result)
    end)
  end)

  --
end)
