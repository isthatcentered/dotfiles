local Parser = require("nope.plenary.PlenaryOutputParser")

describe("PlenaryOutputParser", function()
  local parser

  before_each(function()
    parser = Parser.new()
  end)

  describe("initial state", function()
    it("starts with idle status", function()
      local state = parser:get_state()
      assert.same("idle", state.status)
    end)

    it("starts with empty files", function()
      local state = parser:get_state()
      assert.same({}, state.files)
    end)

    it("starts with zero summary", function()
      local state = parser:get_state()
      assert.same(0, state.summary.total)
      assert.same(0, state.summary.passed)
      assert.same(0, state.summary.failed)
    end)
  end)

  describe("parse_line", function()
    it("parses Testing: line to start file", function()
      parser:parse_line("Testing: \t/path/to/file_spec.lua\t")

      local state = parser:get_state()
      assert.same(1, #state.files)
      assert.same("/path/to/file_spec.lua", state.files[1].path)
      assert.same("pending", state.files[1].status)
    end)

    it("parses Success result correctly", function()
      parser:parse_line("Testing: \t/path/to/file_spec.lua\t")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tMy test suite passes")

      local state = parser:get_state()
      assert.same(1, #state.files[1].tests)
      assert.same("My test suite passes", state.files[1].tests[1].name)
      assert.same("passed", state.files[1].tests[1].status)
      assert.same(1, state.summary.passed)
      assert.same(1, state.summary.total)
    end)

    it("parses Fail result correctly", function()
      parser:parse_line("Testing: \t/path/to/file_spec.lua\t")
      parser:parse_line("\027[31mFail\027[0m\t||\tMy test suite fails")

      local state = parser:get_state()
      assert.same(1, #state.files[1].tests)
      assert.same("My test suite fails", state.files[1].tests[1].name)
      assert.same("failed", state.files[1].tests[1].status)
      assert.same(1, state.summary.failed)
      assert.same(1, state.summary.total)
    end)

    it("captures error message for failed test", function()
      parser:parse_line("Testing: \t/path/to/file_spec.lua\t")
      parser:parse_line("\027[31mFail\027[0m\t||\tMy test fails")
      parser:parse_line("            /path/to/file_spec.lua:17: Expected objects to be the same.")
      parser:parse_line("            Passed in:")
      parser:parse_line("            (boolean) true")
      parser:parse_line("\027[32mSuccess: \027[0m\t3")

      local state = parser:get_state()
      local test = state.files[1].tests[1]
      assert.is_not_nil(test.failure)
      assert.is_truthy(test.failure.message:match("Expected objects to be the same"))
    end)

    it("extracts line number from error message", function()
      parser:parse_line("Testing: \t/path/to/file_spec.lua\t")
      parser:parse_line("\027[31mFail\027[0m\t||\tMy test fails")
      parser:parse_line("            /path/to/file_spec.lua:17: Expected objects to be the same.")
      parser:parse_line("\027[32mSuccess: \027[0m\t0")

      local state = parser:get_state()
      local test = state.files[1].tests[1]
      assert.is_not_nil(test.location)
      assert.same(17, test.location.line)
    end)

    it("handles multiple files in sequence", function()
      parser:parse_line("Testing: \t/path/to/first_spec.lua\t")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tFirst test passes")
      parser:parse_line("\027[32mSuccess: \027[0m\t1")
      parser:parse_line("========================================")

      parser:parse_line("Testing: \t/path/to/second_spec.lua\t")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tSecond test passes")
      parser:parse_line("\027[32mSuccess: \027[0m\t1")

      local state = parser:get_state()
      assert.same(2, #state.files)
      assert.same("/path/to/first_spec.lua", state.files[1].path)
      assert.same("/path/to/second_spec.lua", state.files[2].path)
    end)

    it("accumulates summary across files", function()
      parser:parse_line("Testing: \t/path/to/first_spec.lua\t")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tTest 1")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tTest 2")

      parser:parse_line("Testing: \t/path/to/second_spec.lua\t")
      parser:parse_line("\027[31mFail\027[0m\t||\tTest 3")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tTest 4")

      local state = parser:get_state()
      assert.same(4, state.summary.total)
      assert.same(3, state.summary.passed)
      assert.same(1, state.summary.failed)
    end)

    it("sets file status to failed when has failing tests", function()
      parser:parse_line("Testing: \t/path/to/file_spec.lua\t")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tPassing test")
      parser:parse_line("\027[31mFail\027[0m\t||\tFailing test")
      parser:parse_line("\027[32mSuccess: \027[0m\t1")

      local state = parser:get_state()
      assert.same("failed", state.files[1].status)
    end)

    it("sets file status to passed when all tests pass", function()
      parser:parse_line("Testing: \t/path/to/file_spec.lua\t")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tPassing test 1")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tPassing test 2")
      parser:parse_line("\027[32mSuccess: \027[0m\t2")

      local state = parser:get_state()
      assert.same("passed", state.files[1].status)
    end)

    it("creates pending file from scheduling line", function()
      parser:parse_line("Scheduling: lua/nope/file_spec.lua")

      local state = parser:get_state()
      assert.same(1, #state.files)
      assert.same("lua/nope/file_spec.lua", state.files[1].path)
      assert.same("pending", state.files[1].status)
      assert.same("pending", state.status)
    end)

    it("creates multiple pending files from scheduling lines", function()
      parser:parse_line("Scheduling: lua/nope/first_spec.lua")
      parser:parse_line("Scheduling: lua/nope/second_spec.lua")
      parser:parse_line("Scheduling: lua/nope/third_spec.lua")

      local state = parser:get_state()
      assert.same(3, #state.files)
      assert.same("lua/nope/first_spec.lua", state.files[1].path)
      assert.same("lua/nope/second_spec.lua", state.files[2].path)
      assert.same("lua/nope/third_spec.lua", state.files[3].path)
      for _, file in ipairs(state.files) do
        assert.same("pending", file.status)
      end
    end)

    it("reuses scheduled file when Testing: line is parsed", function()
      parser:parse_line("Scheduling: lua/nope/file_spec.lua")
      parser:parse_line("Testing: \tlua/nope/file_spec.lua\t")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tMy test passes")

      local state = parser:get_state()
      assert.same(1, #state.files) -- no duplicate
      assert.same("lua/nope/file_spec.lua", state.files[1].path)
      assert.same(1, #state.files[1].tests)
      assert.same("My test passes", state.files[1].tests[1].name)
    end)

    it("matches relative scheduled path to absolute Testing path", function()
      parser:parse_line("Scheduling: lua/nope/file_spec.lua")
      parser:parse_line("Testing: \t/Users/dev/project/lua/nope/file_spec.lua\t")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tTest passes")

      local state = parser:get_state()
      assert.same(1, #state.files) -- no duplicate
      assert.same("/Users/dev/project/lua/nope/file_spec.lua", state.files[1].path)
      assert.same("file:/Users/dev/project/lua/nope/file_spec.lua", state.files[1].id)
    end)

    it("handles unexpected error block", function()
      parser:parse_line("Testing: \t/path/to/file_spec.lua\t")
      parser:parse_line("We had an unexpected error: \t{ {")

      local state = parser:get_state()
      assert.same("failed", state.files[1].status)
    end)
  end)

  describe("complete", function()
    it("sets status to done", function()
      parser:parse_line("Testing: \t/path/to/file_spec.lua\t")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tTest passes")
      parser:complete()

      local state = parser:get_state()
      assert.same("done", state.status)
    end)

    it("finalizes pending error collection", function()
      parser:parse_line("Testing: \t/path/to/file_spec.lua\t")
      parser:parse_line("\027[31mFail\027[0m\t||\tTest fails")
      parser:parse_line("            /path/to/file_spec.lua:10: Error message")
      parser:complete()

      local state = parser:get_state()
      local test = state.files[1].tests[1]
      assert.is_not_nil(test.failure)
      assert.same(10, test.location.line)
    end)
  end)

  describe("reset", function()
    it("resets to initial state", function()
      parser:parse_line("Testing: \t/path/to/file_spec.lua\t")
      parser:parse_line("\027[32mSuccess\027[0m\t||\tTest passes")
      parser:complete()

      parser:reset()

      local state = parser:get_state()
      assert.same("idle", state.status)
      assert.same(0, #state.files)
      assert.same(0, state.summary.total)
    end)
  end)
end)
