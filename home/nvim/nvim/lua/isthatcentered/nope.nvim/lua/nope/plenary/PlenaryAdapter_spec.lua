local PlenaryAdapter = require("nope.plenary.PlenaryAdapter")

describe("PlenaryAdapter", function()
  local adapter

  before_each(function()
    adapter = PlenaryAdapter.new()
  end)

  describe("new", function()
    it("creates adapter with name Plenary", function()
      assert.same("Plenary", adapter.name)
    end)
  end)

  describe("get_runner", function()
    it("returns a runner with listen, start, stop", function()
      local runner = adapter:get_runner({
        adapter = "Plenary",
        configuration_path = "scripts/minimal_init.vim",
        key = "test-key",
      })
      assert.is_not_nil(runner)
      assert.is_not_nil(runner.listen)
      assert.is_not_nil(runner.start)
      assert.is_not_nil(runner.stop)
    end)

    it("runs single file when file_path provided", function()
      local runner = adapter:get_runner({
        adapter = "Plenary",
        configuration_path = "scripts/minimal_init.vim",
        file_path = "lua/nope/Signal_spec.lua",
        key = "test-key",
      })
      assert.is_not_nil(runner)
    end)

    it("uses default config_path when not provided", function()
      local runner = adapter:get_runner({
        adapter = "Plenary",
        key = "test-key",
      })
      assert.is_not_nil(runner)
    end)
  end)

  describe("is_test_file", function()
    it("returns true for _spec.lua files", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, "/path/to/my_test_spec.lua")

      assert.is_true(adapter:is_test_file(bufnr))

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns false for regular lua files", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, "/path/to/my_module.lua")

      assert.is_false(adapter:is_test_file(bufnr))

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns false for non-lua files", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, "/path/to/file.ts")

      assert.is_false(adapter:is_test_file(bufnr))

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)
