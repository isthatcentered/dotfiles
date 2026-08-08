local spy = require("luassert.spy")
local ListsEditor = require("scoped.ListsEditor")
local test_utils = require("scoped.test_utils")

local validate_strategy = { validate = function() return nil end }

describe("ListsEditor", function()
  before_each(function()
    test_utils.reset_editor()
  end)

  describe("open", function()
    it("Opening while already opened does nothing", function()
      local lists = {
        { name = "List 1", files = {} },
      }
      local on_open = spy.new(function() end)
      local editor = ListsEditor.new(validate_strategy, on_open, nil, function() return {lists=lists, active_list=nil, active_file=nil} end)
      editor:open()
      local initial_snapshot = test_utils.get_editor_snapshot()

      local result = editor:open()

      assert.same(false, result)
      assert.same(initial_snapshot, test_utils.get_editor_snapshot())
    end)

    it("Opens the lists editor with the given lists", function()
      local lists = {
        { name = "List 1", files = { "Bookmark 1" } },
        { name = "List 2", files = {} },
      }
      local on_open = spy.new(function() end)
      local initial_snapshot = test_utils.get_editor_snapshot()
      local editor = ListsEditor.new(validate_strategy, on_open, nil, function() return {lists=lists, active_list=nil, active_file=nil} end)

      local result = editor:open()

      assert.same(true, result)
      assert.Not.same(initial_snapshot, test_utils.get_editor_snapshot())
      assert.same(2, #test_utils.get_editor_snapshot().windows)
       assert.same({
         "List 1 (1)",
         "  - Bookmark 1",
         "",
         "List 2 (0)",
       }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      -- Check fold is created and closed
      assert.same(1, vim.fn.foldclosed(1))  -- First fold starts at line 1
      assert.same(2, vim.fn.foldclosedend(1))  -- and ends at line 2
      assert.same(-1, vim.fn.foldclosed(4))  -- No fold at line 4 (list has no bookmarks)
    end)

    it("Pressing <CR> on list calls on_open with list_id and nil bookmark_id", function()
      local lists = {
        { name = "List 1", files = {} },
      }
      local on_open = spy.new(function() end)
      local editor = ListsEditor.new(validate_strategy, on_open, nil, function() return {lists=lists, active_list=nil, active_file=nil} end)
      editor:open()

      test_utils.type("<CR>")

      assert.spy(on_open).was.called_with("List 1", nil)
    end)

    it("Pressing <CR> on bookmark calls on_open with list_id and bookmark_id", function()
  local lists = {
    { name = "List 1", files = { "Bookmark 1" } },
  }
  local on_open = spy.new(function() end)
  local editor = ListsEditor.new(validate_strategy, on_open, nil, function() return {lists=lists, active_list=nil, active_file=nil} end)
  editor:open()

      test_utils.type("zoj<CR>")  -- Open fold, move down to bookmark, press enter

      assert.spy(on_open).was.called_with("List 1", "Bookmark 1")
    end)

    it("Opens with cursor at active list header when active_file is nil", function()
      local lists = {
        { name = "List 1", files = { "Bookmark 1" } },
        { name = "List 2", files = {} },
      }
      local on_open = spy.new(function() end)
      local editor = ListsEditor.new(validate_strategy, on_open, nil, function() return {lists=lists, active_list="List 2", active_file=nil} end)
      editor:open()

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.same(4, cursor[1])  -- Line 4 is "List 2 (0)"
    end)

    it("Opens with cursor at active file and list unfolded when active_file is provided", function()
      local lists = {
        { name = "List 1", files = { "Bookmark 1", "Bookmark 2" } },
        { name = "List 2", files = {} },
      }
      local on_open = spy.new(function() end)
      local editor = ListsEditor.new(validate_strategy, on_open, nil, function() return {lists=lists, active_list="List 1", active_file="Bookmark 2"} end)
      editor:open()

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.same(3, cursor[1])  -- Line 3 is "  - Bookmark 2"
      assert.same(-1, vim.fn.foldclosed(1))  -- Fold at line 1 (List 1) should be open
    end)
  end)

  describe("close", function()
    it("Closes the window", function()
  local lists = {
    { name = "List 1", files = {} },
  }
  local on_open = spy.new(function() end)
  local initial_snapshot = test_utils.get_editor_snapshot()
  local editor = ListsEditor.new(validate_strategy, on_open, nil, function() return {lists=lists, active_list=nil, active_file=nil} end)

  editor:open()
  editor:close()

      assert.same(initial_snapshot, test_utils.get_editor_snapshot())
    end)

    it("Closing when not opened does nothing", function()
      local initial_snapshot = test_utils.get_editor_snapshot()
      local editor = ListsEditor.new(validate_strategy, nil, nil, function() return {} end)

      editor:close()

      assert.same(initial_snapshot, test_utils.get_editor_snapshot())
    end)

    it("Pressing <Esc><Esc> closes the window", function()
  local lists = {
    { name = "List 1", files = {} },
  }
  local on_open = spy.new(function() end)
  local initial_snapshot = test_utils.get_editor_snapshot()
  local editor = ListsEditor.new(validate_strategy, on_open, nil, function() return {lists=lists, active_list=nil, active_file=nil} end)

  editor:open()
  test_utils.type("<Esc><Esc>")

      assert.same(initial_snapshot, test_utils.get_editor_snapshot())
    end)
  end)
end)
