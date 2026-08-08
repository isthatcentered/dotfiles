local CenteredToBufferPositionStrategy = require("scoped.ScratchWindow.CenteredToBufferPositionStrategy")
local test_utils = require("scoped.test_utils")

describe("CenteredToBufferPositionStrategy", function()
  before_each(function()
    test_utils.reset_editor()
  end)

  describe("get_position", function()
    it("Calcultes position and size relative to the given origin buffer", function()
      -- Set editor dimensions
      vim.o.columns = 100
      vim.o.lines = 100

      local buffer_id = vim.api.nvim_create_buf(false, true)
      local window_id = vim.api.nvim_open_win(buffer_id, false, {
        relative = "editor",
        width = 100,
        height = 100,
        col = 0,
        row = 0,
      })

      local strategy = CenteredToBufferPositionStrategy.new(300, 300, 0.8, 0.5)
      local position = strategy.get_specs(buffer_id, 1234)

      assert.same({
        border = "rounded",
        title = "Scratch",
        title_pos = "center",
        col = 10, -- 80% of 100 - 20% left divided by 2
        row = 25, -- 50% of 100 - 50% left divided by 2
        width = 80, -- 80% of window by default
        height = 50, -- 50% of window by default
        relative = "win",
      }, position)
    end)

    it("Dimensions are capped to max_width and max_height", function()
      -- Set editor dimensions
      vim.o.columns = 100
      vim.o.lines = 100

      local buffer_id = vim.api.nvim_create_buf(false, true)
      local window_id = vim.api.nvim_open_win(buffer_id, false, {
        relative = "editor",
        width = 100,
        height = 100,
        col = 0,
        row = 0,
      })

      local strategy = CenteredToBufferPositionStrategy.new(10, 20, 1, 1)
      local position = strategy.get_specs(buffer_id, 1234)

      assert.same({
        border = "rounded",
        title = "Scratch",
        title_pos = "center",
        col = 45,
        row = 40,
        width = 10,
        height = 20,
        relative = "win",
      }, position)
    end)
  end)
end)
