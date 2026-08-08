local spy = require("luassert.spy")
local ScratchWindow = require("scoped.ScratchWindow")
local test_utils = require("scoped.test_utils")

describe("ScratchWindow", function()
  before_each(function()
    test_utils.reset_editor()
  end)

  local make_position_strategy = function()
    return {
      get_specs = spy.new(function(origin_buffer, target_buffer)
        return {
          col = 10,
          row = 5,
          width = 30,
          height = 10,
          relative = "editor",
        }
      end),
    }
  end

  describe("open", function()
    it("Opening the window while already opened does nothing", function()
      local window = ScratchWindow.new({
        position_strategy = make_position_strategy(),
      })
      local buffer_id = vim.api.nvim_create_buf(false, true)
      window:open(buffer_id)
      local initial_snapshot = test_utils.get_editor_snapshot()

      local result = window:open(buffer_id)

      assert.same(false, result)
      assert.same(initial_snapshot, test_utils.get_editor_snapshot())
    end)

    it("Opens the scratch window with the given buffer", function()
      local position_strategy = make_position_strategy()
      local window = ScratchWindow.new({
        position_strategy = position_strategy,
      })
      local buffer_id = vim.api.nvim_create_buf(false, true)
      local initial_snapshot = test_utils.get_editor_snapshot()

      local result = window:open(buffer_id)

      assert.same(true, result)
      assert.Not.same(initial_snapshot, test_utils.get_editor_snapshot())
      assert.same(2, #test_utils.get_editor_snapshot().windows)
      assert.same(buffer_id, vim.api.nvim_win_get_buf(0))
      assert.spy(position_strategy.get_specs).was.called_with(1, buffer_id)
    end)

    it("Uses position strategy to place window", function()
      local custom_strategy = {
        get_specs = function(origin_buffer, target_buffer)
          return {
            col = 20,
            row = 15,
            width = 40,
            height = 20,
            relative = "editor",
          }
        end,
      }
      local window = ScratchWindow.new({
        position_strategy = custom_strategy,
      })
      local buffer_id = vim.api.nvim_create_buf(false, true)

      window:open(buffer_id)

      assert.same({
        col = 20,
        height = 20,
        row = 15,
        width = 40,
        zindex = 50,
        anchor = "NW",
        external = false,
        focusable = true,
        mouse = true,
        hide = false,
        relative = "editor",
      }, vim.api.nvim_win_get_config(window.window_id))
    end)

    it("Resets on every open", function()
      local position_strategy = make_position_strategy()
      local window = ScratchWindow.new({
        position_strategy = position_strategy,
      })
      local buffer_id1 = vim.api.nvim_create_buf(false, true)
      local buffer_id2 = vim.api.nvim_create_buf(false, true)

      window:open(buffer_id1)
      window:close()
      window:open(buffer_id2)

      assert.same(buffer_id2, vim.api.nvim_get_current_buf())
      assert.spy(position_strategy.get_specs).was.called_with(1, buffer_id1)
      assert.spy(position_strategy.get_specs).was.called_with(1, buffer_id2)
    end)

    it("Recomputes window specs on every open", function()
      local custom_strategy = {
        get_specs = function(origin_buffer, target_buffer)
          return {
            col = 20,
            row = 15,
            width = 40,
            height = 20,
            relative = "editor",
          }
        end,
      }
      local window = ScratchWindow.new({
        position_strategy = custom_strategy,
      })
      local buffer_id = vim.api.nvim_create_buf(false, true)

      window:open(buffer_id)

      assert.same({
        col = 20,
        height = 20,
        row = 15,
        width = 40,
        zindex = 50,
        anchor = "NW",
        external = false,
        focusable = true,
        mouse = true,
        hide = false,
        relative = "editor",
      }, vim.api.nvim_win_get_config(window.window_id))
    end)
  end)

  describe("close", function()
    it("Closes the window", function()
      local window = ScratchWindow.new({
        position_strategy = make_position_strategy(),
      })
      local buffer_id = vim.api.nvim_create_buf(false, true)
      local intiial_snapshot = test_utils.get_editor_snapshot()

      window:open(buffer_id)
      window:close()

      assert.same(intiial_snapshot, test_utils.get_editor_snapshot())
    end)

    it("Closing when not opened does nothing", function()
      local window = ScratchWindow.new({
        position_strategy = make_position_strategy(),
      })
      local initial_snapshot = test_utils.get_editor_snapshot()

      window:close()

      assert.same(initial_snapshot, test_utils.get_editor_snapshot())
    end)
  end)

  describe("autocmd behavior", function()
    it("Closes window on buffer switch", function()
      local window = ScratchWindow.new({
        position_strategy = make_position_strategy(),
      })
      local buffer_id = vim.api.nvim_create_buf(false, true)
      local initial_snapshot = test_utils.get_editor_snapshot()

      window:open(buffer_id)
      test_utils.type(":bnext<CR>")

      assert.same(initial_snapshot, test_utils.get_editor_snapshot())
    end)

    it("Closes window on manual quit", function()
      local window = ScratchWindow.new({
        position_strategy = make_position_strategy(),
      })
      local buffer_id = vim.api.nvim_create_buf(false, true)
      local initial_snapshot = test_utils.get_editor_snapshot()

      window:open(buffer_id)
      test_utils.type(":q<CR>")

      assert.same(initial_snapshot, test_utils.get_editor_snapshot())
    end)
  end)
end)
