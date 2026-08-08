local Registry = require("scoped.Registry")
local test_utils = require("scoped.test_utils")

describe("Registry", function()
  before_each(function()
    test_utils.reset_editor()
  end)

  describe("create_list", function()
    it("creates a new list", function()
      local registry = Registry.new()

      local result = registry:create_list("My List")

      assert.same(true, result)
      assert.same(1, #registry.lists)
      assert.same("My List", registry.lists[1].name)
      assert.same({}, registry.lists[1].files)
    end)

    it("fails with empty name", function()
      local registry = Registry.new()

      local result = registry:create_list("")

      assert.same(false, result)
      assert.same(0, #registry.lists)
    end)

    it("fails with nil name", function()
      local registry = Registry.new()

      local result = registry:create_list(nil)

      assert.same(false, result)
      assert.same(0, #registry.lists)
    end)

    it("fails with duplicate name", function()
      local registry = Registry.new()
      registry:create_list("My List")

      local result = registry:create_list("My List")

      assert.same(false, result)
      assert.same(1, #registry.lists)
    end)
  end)

  describe("remove_list", function()
    it("removes existing list", function()
      local registry = Registry.new()
      registry:create_list("My List")

      local result = registry:remove_list("My List")

      assert.same(true, result)
      assert.same(0, #registry.lists)
    end)

    it("fails with non-existing list", function()
      local registry = Registry.new()

      local result = registry:remove_list("Non-existing")

      assert.same(false, result)
    end)

    it("removes window bindings when list is removed", function()
      local registry = Registry.new()
      local window_id = vim.api.nvim_get_current_win()
      registry:create_list("My List")
      registry:bind_list_to_window("My List", window_id)

      registry:remove_list("My List")

      assert.same(nil, registry:get_bound_list(window_id))
    end)
  end)

  describe("add_file_to_list", function()
    it("adds file to existing list", function()
      local registry = Registry.new()
      registry:create_list("My List")

      local result = registry:add_file_to_list("My List", "file.txt")

      assert.same(true, result)
      assert.same({"file.txt"}, registry.lists[1].files)
    end)

    it("normalizes path to relative", function()
      local registry = Registry.new()
      registry:create_list("My List")

      local result = registry:add_file_to_list("My List", vim.fn.getcwd() .. "/file.txt")

      assert.same(true, result)
      assert.same({"file.txt"}, registry.lists[1].files)
    end)

    it("fails with non-existing list", function()
      local registry = Registry.new()

      local result = registry:add_file_to_list("Non-existing", "file.txt")

      assert.same(false, result)
    end)

    it("fails with empty file path", function()
      local registry = Registry.new()
      registry:create_list("My List")

      local result = registry:add_file_to_list("My List", "")

      assert.same(false, result)
    end)

    it("does not add duplicate files", function()
      local registry = Registry.new()
      registry:create_list("My List")
      registry:add_file_to_list("My List", "file.txt")

      local result = registry:add_file_to_list("My List", "file.txt")

      assert.same(false, result)
      assert.same({"file.txt"}, registry.lists[1].files)
    end)
  end)

  describe("remove_file_from_list", function()
    it("removes file from list", function()
      local registry = Registry.new()
      registry:create_list("My List")
      registry:add_file_to_list("My List", "file1.txt")
      registry:add_file_to_list("My List", "file2.txt")

      local result = registry:remove_file_from_list("My List", "file1.txt")

      assert.same(true, result)
      assert.same({"file2.txt"}, registry.lists[1].files)
    end)

    it("clears last_opened if removed file was last opened", function()
      local registry = Registry.new()
      registry:create_list("My List")
      registry:add_file_to_list("My List", "file1.txt")
      registry:add_file_to_list("My List", "file2.txt")
      registry:file_opened("file1.txt")

      registry:remove_file_from_list("My List", "file1.txt")

      assert.same(nil, registry.lists[1].last_opened)
    end)

    it("fails with non-existing list", function()
      local registry = Registry.new()

      local result = registry:remove_file_from_list("Non-existing", "file.txt")

      assert.same(false, result)
    end)

    it("fails with non-existing file", function()
      local registry = Registry.new()
      registry:create_list("My List")

      local result = registry:remove_file_from_list("My List", "file.txt")

      assert.same(false, result)
    end)
  end)

  describe("file_opened", function()
    it("sets last_opened for lists containing the file", function()
      local registry = Registry.new()
      registry:create_list("List1")
      registry:create_list("List2")
      registry:add_file_to_list("List1", "file.txt")
      registry:add_file_to_list("List2", "file.txt")
      registry:add_file_to_list("List2", "other.txt")

      registry:file_opened("file.txt")

      assert.same("file.txt", registry.lists[1].last_opened)
      assert.same("file.txt", registry.lists[2].last_opened)
    end)
  end)

  describe("file_opened_in_window", function()
    it("sets last_opened for bound list if path is in list", function()
      local registry = Registry.new()
      registry:create_list("List1")
      registry:add_file_to_list("List1", "file1.txt")
      registry:add_file_to_list("List1", "file2.txt")
      local window_id = vim.api.nvim_get_current_win()
      registry:bind_list_to_window("List1", window_id)

      registry:file_opened_in_window("file1.txt", window_id)

      assert.same("file1.txt", registry.lists[1].last_opened)
    end)

    it("does nothing if no bound list", function()
      local registry = Registry.new()
      registry:create_list("List1")
      registry:add_file_to_list("List1", "file1.txt")
      local window_id = vim.api.nvim_get_current_win()

      registry:file_opened_in_window("file1.txt", window_id)

      assert.is_nil(registry.lists[1].last_opened)
    end)

    it("does nothing if path not in bound list", function()
      local registry = Registry.new()
      registry:create_list("List1")
      registry:add_file_to_list("List1", "file1.txt")
      local window_id = vim.api.nvim_get_current_win()
      registry:bind_list_to_window("List1", window_id)

      registry:file_opened_in_window("file2.txt", window_id)

      assert.is_nil(registry.lists[1].last_opened)
    end)
  end)

  describe("next_file_in_window", function()
    it("returns next file in bound list", function()
      local registry = Registry.new()
      registry:create_list("List1")
      registry:add_file_to_list("List1", "file1.txt")
      registry:add_file_to_list("List1", "file2.txt")
      local window_id = vim.api.nvim_get_current_win()
      registry:bind_list_to_window("List1", window_id)
      registry:file_opened_in_window("file1.txt", window_id)

      local result = registry:next_file_in_window(window_id)

      assert.same("file2.txt", result)
    end)

    it("returns nil if no bound list", function()
      local registry = Registry.new()
      local window_id = vim.api.nvim_get_current_win()

      local result = registry:next_file_in_window(window_id)

      assert.is_nil(result)
    end)
  end)

  describe("previous_file_in_window", function()
    it("returns previous file in bound list", function()
      local registry = Registry.new()
      registry:create_list("List1")
      registry:add_file_to_list("List1", "file1.txt")
      registry:add_file_to_list("List1", "file2.txt")
      local window_id = vim.api.nvim_get_current_win()
      registry:bind_list_to_window("List1", window_id)
      registry:file_opened_in_window("file2.txt", window_id)

      local result = registry:previous_file_in_window(window_id)

      assert.same("file1.txt", result)
    end)

    it("returns nil if no bound list", function()
      local registry = Registry.new()
      local window_id = vim.api.nvim_get_current_win()

      local result = registry:previous_file_in_window(window_id)

      assert.is_nil(result)
    end)
  end)

  describe("next_file_in_list", function()
    it("returns first file if no last_opened", function()
      local registry = Registry.new()
      registry:create_list("My List")
      registry:add_file_to_list("My List", "file1.txt")
      registry:add_file_to_list("My List", "file2.txt")

      local result = registry:next_file_in_list("My List")

      assert.same("file1.txt", result)
      assert.same("file1.txt", registry.lists[1].last_opened)
    end)

    it("returns next file after last_opened", function()
      local registry = Registry.new()
      registry:create_list("My List")
      registry:add_file_to_list("My List", "file1.txt")
      registry:add_file_to_list("My List", "file2.txt")
      registry:add_file_to_list("My List", "file3.txt")
      registry:file_opened("file1.txt")

      local result = registry:next_file_in_list("My List")

      assert.same("file2.txt", result)
      assert.same("file2.txt", registry.lists[1].last_opened)
    end)

    it("wraps around to first file", function()
      local registry = Registry.new()
      registry:create_list("My List")
      registry:add_file_to_list("My List", "file1.txt")
      registry:add_file_to_list("My List", "file2.txt")
      registry:file_opened("file2.txt")

      local result = registry:next_file_in_list("My List")

      assert.same("file1.txt", result)
    end)

    it("returns nil for empty list", function()
      local registry = Registry.new()
      registry:create_list("My List")

      local result = registry:next_file_in_list("My List")

      assert.same(nil, result)
    end)

    it("returns nil for non-existing list", function()
      local registry = Registry.new()

      local result = registry:next_file_in_list("Non-existing")

      assert.same(nil, result)
    end)
  end)

  describe("previous_file_in_list", function()
    it("returns last file if no last_opened", function()
      local registry = Registry.new()
      registry:create_list("My List")
      registry:add_file_to_list("My List", "file1.txt")
      registry:add_file_to_list("My List", "file2.txt")

      local result = registry:previous_file_in_list("My List")

      assert.same("file2.txt", result)
      assert.same("file2.txt", registry.lists[1].last_opened)
    end)

    it("returns previous file before last_opened", function()
      local registry = Registry.new()
      registry:create_list("My List")
      registry:add_file_to_list("My List", "file1.txt")
      registry:add_file_to_list("My List", "file2.txt")
      registry:add_file_to_list("My List", "file3.txt")
      registry:file_opened("file3.txt")

      local result = registry:previous_file_in_list("My List")

      assert.same("file2.txt", result)
      assert.same("file2.txt", registry.lists[1].last_opened)
    end)

    it("wraps around to last file", function()
      local registry = Registry.new()
      registry:create_list("My List")
      registry:add_file_to_list("My List", "file1.txt")
      registry:add_file_to_list("My List", "file2.txt")
      registry:file_opened("file1.txt")

      local result = registry:previous_file_in_list("My List")

      assert.same("file2.txt", result)
    end)

    it("returns nil for empty list", function()
      local registry = Registry.new()
      registry:create_list("My List")

      local result = registry:previous_file_in_list("My List")

      assert.same(nil, result)
    end)

    it("returns nil for non-existing list", function()
      local registry = Registry.new()

      local result = registry:previous_file_in_list("Non-existing")

      assert.same(nil, result)
    end)
  end)

  describe("set_lists", function()
    it("replaces all lists", function()
      local registry = Registry.new()
      registry:create_list("Old List")

      registry:set_lists({
        { name = "New List", files = { "file1.txt" } }
      })

      assert.same(1, #registry.lists)
      assert.same("New List", registry.lists[1].name)
      assert.same({"file1.txt"}, registry.lists[1].files)
    end)

    it("handles duplicate names by appending _new", function()
      local registry = Registry.new()

      registry:set_lists({
        { name = "List", files = {} },
        { name = "List", files = {} },
        { name = "List", files = {} }
      })

      assert.same(3, #registry.lists)
      assert.same("List", registry.lists[1].name)
      assert.same("List_new", registry.lists[2].name)
      assert.same("List_new_new", registry.lists[3].name)
    end)

    it("dedupes files within lists", function()
      local registry = Registry.new()

      registry:set_lists({
        { name = "List", files = { "file.txt", "file.txt", "other.txt" } }
      })

      assert.same({"file.txt", "other.txt"}, registry.lists[1].files)
    end)

    it("preserves last_opened if file still exists", function()
      local registry = Registry.new()
      registry:create_list("Old List")
      registry:add_file_to_list("Old List", "keep.txt")
      registry:add_file_to_list("Old List", "remove.txt")
      registry:file_opened("keep.txt")

      registry:set_lists({
        { name = "Old List", files = { "keep.txt", "new.txt" } }
      })

      assert.same("keep.txt", registry.lists[1].last_opened)
    end)

    it("clears last_opened if file no longer exists", function()
      local registry = Registry.new()
      registry:create_list("Old List")
      registry:add_file_to_list("Old List", "remove.txt")
      registry:file_opened("remove.txt")

      registry:set_lists({
        { name = "Old List", files = { "new.txt" } }
      })

      assert.same(nil, registry.lists[1].last_opened)
    end)

    it("removes window bindings for non-existent lists", function()
      local registry = Registry.new()
      local window_id = vim.api.nvim_get_current_win()
      registry:create_list("Old List")
      registry:bind_list_to_window("Old List", window_id)

      registry:set_lists({})

      assert.same(nil, registry:get_bound_list(window_id))
    end)
  end)

  describe("bind_list_to_window", function()
    it("binds list to window", function()
      local registry = Registry.new()
      local window_id = vim.api.nvim_get_current_win()
      registry:create_list("My List")

      local result = registry:bind_list_to_window("My List", window_id)

      assert.same(true, result)
      assert.same("My List", registry:get_bound_list(window_id))
    end)

    it("fails with invalid window", function()
      local registry = Registry.new()
      registry:create_list("My List")

      local result = registry:bind_list_to_window("My List", 999)

      assert.same(false, result)
    end)

    it("fails with non-existing list", function()
      local registry = Registry.new()
      local window_id = vim.api.nvim_get_current_win()

      local result = registry:bind_list_to_window("Non-existing", window_id)

      assert.same(false, result)
    end)

    it("overwrites previous binding", function()
      local registry = Registry.new()
      local window_id = vim.api.nvim_get_current_win()
      registry:create_list("List1")
      registry:create_list("List2")
      registry:bind_list_to_window("List1", window_id)

      registry:bind_list_to_window("List2", window_id)

      assert.same("List2", registry:get_bound_list(window_id))
    end)
  end)

  describe("unbind_list_from_window", function()
    it("unbinds list from window", function()
      local registry = Registry.new()
      local window_id = vim.api.nvim_get_current_win()
      registry:create_list("My List")
      registry:bind_list_to_window("My List", window_id)

      local result = registry:unbind_list_from_window("My List", window_id)

      assert.same(true, result)
      assert.same(nil, registry:get_bound_list(window_id))
    end)

    it("fails if not bound", function()
      local registry = Registry.new()
      local window_id = vim.api.nvim_get_current_win()

      local result = registry:unbind_list_from_window("My List", window_id)

      assert.same(false, result)
    end)
  end)

  describe("serialize/deserialize", function()
    it("preserves window_bindings after serialization round-trip", function()
      local registry = Registry.new("test-id")
      local window_id = vim.api.nvim_get_current_win()
      registry:create_list("My List")
      registry:bind_list_to_window("My List", window_id)

      local serialized = registry:serialize()
      local new_registry = Registry.new("test-id")
      new_registry:deserialize(serialized)

      assert.same("My List", new_registry.window_bindings[window_id])
    end)

    it("handles JSON string key conversion for window_bindings", function()
      local registry = Registry.new("test-id")
      local data = {
        lists = { { name = "List1", files = {}, last_opened = nil } },
        window_bindings = { ["1001"] = "List1" },
      }

      registry:deserialize(data)

      assert.same("List1", registry.window_bindings[1001])
      assert.is_nil(registry.window_bindings["1001"])
    end)
  end)

  describe("get_bound_list", function()
    it("returns bound list", function()
      local registry = Registry.new()
      local window_id = vim.api.nvim_get_current_win()
      registry:create_list("My List")
      registry:bind_list_to_window("My List", window_id)

      local result = registry:get_bound_list(window_id)

      assert.same("My List", result)
    end)

    it("returns nil for unbound window", function()
      local registry = Registry.new()
      local window_id = vim.api.nvim_get_current_win()

      local result = registry:get_bound_list(window_id)

      assert.same(nil, result)
    end)

    it("returns nil for invalid window", function()
      local registry = Registry.new()

      local result = registry:get_bound_list(999)

      assert.same(nil, result)
    end)
  end)

  describe("events", function()
    it("emits list_created on create_list success", function()
      local registry = Registry.new()
      local received = nil
      registry:listen(function(event) received = event end)

      registry:create_list("My List")

      assert.same("list_created", received.kind)
      assert.same({ list_name = "My List" }, received.payload)
    end)

    it("does not emit list_created on create_list failure", function()
      local registry = Registry.new()
      registry:create_list("My List")
      local received = nil
      registry:listen(function(event) received = event end)

      registry:create_list("My List")

      assert.is_nil(received)
    end)

    it("emits list_removed on remove_list success", function()
      local registry = Registry.new()
      registry:create_list("My List")
      local received = nil
      registry:listen(function(event) received = event end)

      registry:remove_list("My List")

      assert.same("list_removed", received.kind)
      assert.same({ list_name = "My List" }, received.payload)
    end)

    it("does not emit list_removed on remove_list failure", function()
      local registry = Registry.new()
      local received = nil
      registry:listen(function(event) received = event end)

      registry:remove_list("Non-existing")

      assert.is_nil(received)
    end)

    it("emits file_added on add_file_to_list success", function()
      local registry = Registry.new()
      registry:create_list("My List")
      local received = nil
      registry:listen(function(event) received = event end)

      registry:add_file_to_list("My List", "file.txt")

      assert.same("file_added", received.kind)
      assert.same({ list_name = "My List", file_path = "file.txt" }, received.payload)
    end)

    it("does not emit file_added on add_file_to_list failure", function()
      local registry = Registry.new()
      local received = nil
      registry:listen(function(event) received = event end)

      registry:add_file_to_list("Non-existing", "file.txt")

      assert.is_nil(received)
    end)

    it("emits file_removed on remove_file_from_list success", function()
      local registry = Registry.new()
      registry:create_list("My List")
      registry:add_file_to_list("My List", "file.txt")
      local received = nil
      registry:listen(function(event) received = event end)

      registry:remove_file_from_list("My List", "file.txt")

      assert.same("file_removed", received.kind)
      assert.same({ list_name = "My List", file_path = "file.txt" }, received.payload)
    end)

    it("does not emit file_removed on remove_file_from_list failure", function()
      local registry = Registry.new()
      local received = nil
      registry:listen(function(event) received = event end)

      registry:remove_file_from_list("Non-existing", "file.txt")

      assert.is_nil(received)
    end)

    it("emits list_bound on bind_list_to_window success", function()
      local registry = Registry.new()
      registry:create_list("My List")
      local window_id = vim.api.nvim_get_current_win()
      local received = nil
      registry:listen(function(event) received = event end)

      registry:bind_list_to_window("My List", window_id)

      assert.same("list_bound", received.kind)
      assert.same({ list_name = "My List", window_id = window_id }, received.payload)
    end)

    it("does not emit list_bound on bind_list_to_window failure", function()
      local registry = Registry.new()
      local received = nil
      registry:listen(function(event) received = event end)

      registry:bind_list_to_window("Non-existing", 999)

      assert.is_nil(received)
    end)

    it("emits list_unbound on unbind_list_from_window success", function()
      local registry = Registry.new()
      registry:create_list("My List")
      local window_id = vim.api.nvim_get_current_win()
      registry:bind_list_to_window("My List", window_id)
      local received = nil
      registry:listen(function(event) received = event end)

      registry:unbind_list_from_window("My List", window_id)

      assert.same("list_unbound", received.kind)
      assert.same({ list_name = "My List", window_id = window_id }, received.payload)
    end)

    it("does not emit list_unbound on unbind_list_from_window failure", function()
      local registry = Registry.new()
      local window_id = vim.api.nvim_get_current_win()
      local received = nil
      registry:listen(function(event) received = event end)

      registry:unbind_list_from_window("My List", window_id)

      assert.is_nil(received)
    end)

    it("emits lists_changed on set_lists", function()
      local registry = Registry.new()
      local received = nil
      registry:listen(function(event) received = event end)

      registry:set_lists({ { name = "New List", files = { "file.txt" } } })

      assert.same("lists_changed", received.kind)
      assert.same(1, #received.payload.lists)
      assert.same("New List", received.payload.lists[1].name)
    end)

    it("emits deserialized on deserialize", function()
      local registry = Registry.new()
      local received = nil
      registry:listen(function(event) received = event end)

      registry:deserialize({
        lists = { { name = "List1", files = {}, last_opened = nil } },
        window_bindings = {},
      })

      assert.same("deserialized", received.kind)
      assert.same(1, #received.payload.lists)
      assert.same("List1", received.payload.lists[1].name)
    end)
  end)
end)