local test_utils = require("scoped.test_utils")
local Scoped = require("scoped.Scoped")

describe("Scoped", function()
  before_each(function()
    test_utils.reset_editor()
  end)

  describe("remove_current_file_from_current_list", function()
    it("removes file from current list", function()
      local scoped = Scoped.new()
      local window_id = vim.api.nvim_get_current_win()
      scoped.registry:create_list("Test List")
      scoped.registry:bind_list_to_window("Test List", window_id)
      scoped.registry:add_file_to_list("Test List", "lua/scoped/fixtures/a.txt")

      -- Simulate buffer with file
      vim.api.nvim_buf_set_name(0, "lua/scoped/fixtures/a.txt")

      scoped:remove_current_file_from_current_list()

      local list = scoped.registry.lists[1]
      assert.same({}, list.files)
    end)

    it("errors if no list bound to window", function()
      local scoped = Scoped.new()

      assert.has_error(function()
        scoped:remove_current_file_from_current_list()
      end, "No current list bound to the window")
    end)

    it("errors if no file in buffer", function()
      local scoped = Scoped.new()
      local window_id = vim.api.nvim_get_current_win()
      scoped.registry:create_list("Test List")
      scoped.registry:bind_list_to_window("Test List", window_id)

      assert.has_error(function()
        scoped:remove_current_file_from_current_list()
      end, "No current file in buffer")
    end)

    it("skips if file not in list", function()
      local scoped = Scoped.new()
      local window_id = vim.api.nvim_get_current_win()
      scoped.registry:create_list("Test List")
      scoped.registry:bind_list_to_window("Test List", window_id)

      -- Simulate buffer with file not in list
      vim.api.nvim_buf_set_name(0, "lua/scoped/fixtures/b.txt")

      -- Should not error, just skip
      scoped:remove_current_file_from_current_list()

      local list = scoped.registry.lists[1]
      assert.same({}, list.files)
    end)
  end)

  describe("create_list", function()
    it("creates a new list", function()
      local scoped = Scoped.new()

      scoped:create_list("New List")

      assert.same(1, #scoped.registry.lists)
      assert.same("New List", scoped.registry.lists[1].name)
    end)

    it("errors if name is empty", function()
      local scoped = Scoped.new()

      assert.has_error(function()
        scoped:create_list("")
      end, "List name cannot be empty")
    end)

    it("errors if list already exists", function()
      local scoped = Scoped.new()
      scoped:create_list("Test List")

      assert.has_error(function()
        scoped:create_list("Test List")
      end, "List already exists")
    end)
  end)

  describe("generate_scratch_name", function()
    it("returns base_name if available", function()
      local scoped = Scoped.new()

      local name = scoped:generate_scratch_name("New List")

      assert.same("New List", name)
    end)

    it("returns base_name_01 if base_name exists", function()
      local scoped = Scoped.new()
      scoped:create_list("Test List")

      local name = scoped:generate_scratch_name("Test List")

      assert.same("Test List_01", name)
    end)

    it("returns base_name_02 if _01 exists", function()
      local scoped = Scoped.new()
      scoped:create_list("Test List")
      scoped:create_list("Test List_01")

      local name = scoped:generate_scratch_name("Test List")

      assert.same("Test List_02", name)
    end)

    it("defaults to 'Scratch list' if base_name is empty", function()
      local scoped = Scoped.new()

      local name = scoped:generate_scratch_name("")

      assert.same("Scratch list", name)
    end)

    it("defaults to 'Scratch list' if base_name is whitespace", function()
      local scoped = Scoped.new()

      local name = scoped:generate_scratch_name("   ")

      assert.same("Scratch list", name)
    end)

    it("increments from 'Scratch list' if default is taken", function()
      local scoped = Scoped.new()
      scoped:create_list("Scratch list")

      local name = scoped:generate_scratch_name("")

      assert.same("Scratch list_01", name)
    end)
  end)

  describe("has_bound_list", function()
    it("returns true if window has bound list", function()
      local scoped = Scoped.new()
      local window_id = vim.api.nvim_get_current_win()
      scoped:create_list("Test List")
      scoped:bind_current_window_to_list("Test List")

      local result = scoped:has_bound_list(window_id)

      assert.same(true, result)
    end)

    it("returns false if window has no bound list", function()
      local scoped = Scoped.new()
      local window_id = vim.api.nvim_get_current_win()

      local result = scoped:has_bound_list(window_id)

      assert.same(false, result)
    end)

    it("transforms window_id 0 to current window", function()
      local scoped = Scoped.new()
      scoped:create_list("Test List")
      scoped:bind_current_window_to_list("Test List")

      local result = scoped:has_bound_list(0)

      assert.same(true, result)
    end)

    it("returns false for invalid window_id", function()
      local scoped = Scoped.new()

      local result = scoped:has_bound_list(99999)

      assert.same(false, result)
    end)
  end)
end)