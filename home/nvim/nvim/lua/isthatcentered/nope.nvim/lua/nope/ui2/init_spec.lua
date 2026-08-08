local C = require("nope.ui2")

---@return C.BoxConstraints
local function unconstrained()
  return {
    max_width = math.huge,
    min_width = 0,
  }
end

describe("flutter style", function()
  describe("render", function()
    it("renders to non-modifiable buffer", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

      local component = C.Text("content")
      C.render(buf, component, unconstrained())

      assert.same({ "content" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      -- Buffer should remain non-modifiable after render
      assert.is_false(vim.api.nvim_get_option_value("modifiable", { buf = buf }))
    end)
  end)

  describe("Text", function()
    it("No constraint takes all the necessary space", function()
      local component = C.Text("content")

      C.render(0, component, unconstrained())

      assert.same({
        "content",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Truncates text to follow width constraint", function()
      local component = C.Text("content")

      C.render(0, component, {
        max_width = 3,
        min_width = 0,
      })

      assert.same({
        "con",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Expands to given min_width", function()
      local component = C.Text("A")

      C.render(0, component, {
        max_width = math.huge,
        min_width = 4,
      })

      assert.same({
        "A   ",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)
  end)

  describe("Array", function()
    it("Renders children left to right", function()
      local component = C.Array({
        C.Text("A"),
        C.Text("B"),
        C.Text("C"),
      })

      C.render(0, component, unconstrained())

      assert.same({
        "ABC",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Renders at the correct x offset", function()
      local component = C.Array({
        C.Array({
          C.Text("A"),
        }),
        C.Array({
          C.Text("B"),
        }),
      })

      C.render(0, component, unconstrained())

      assert.same({
        "AB",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Width takes flex children into account", function()
      local component = C.Array({
        C.Array({
          C.Text("A"),
          C.Flex(1, C.Text("B")),
        }),
        C.Array({
          C.Text("C"),
        }),
      })

      C.render(0, component, { min_width = 0, max_width = 4 })

      assert.same({
        "AB  ",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Renders at the correct y offset", function()
      local component = C.Stack({
        C.Array({
          C.Text("A"),
        }),
        C.Array({
          C.Text("B"),
        }),
      })

      C.render(0, component, unconstrained())

      assert.same({
        "A",
        "B",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Non flex children take their intrinsic size", function()
      local component = C.Array({
        C.Text("AA"),
        C.Text("BBBB"),
        C.Text("C"),
      })

      C.render(0, component, { max_width = 7, min_width = 0 })

      assert.same({
        "AABBBBC",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Distributes the non fixed space between flex chldren", function()
      local component = C.Array({
        C.Flex(1, C.Text("A")),
        C.Flex(1, C.Text("B")),
        C.Text("C"),
        C.Text("D"),
      })

      C.render(0, component, { min_width = 0, max_width = 6 })

      assert.same({
        "A B CD",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Distributes flex space based on weight", function()
      local component = C.Array({
        C.Flex(2, C.Text("A")),
        C.Flex(1, C.Text("B")),
      })

      C.render(0, component, { min_width = 0, max_width = 6 })

      assert.same({
        "A   B ",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Last flex child get remainder of fractional width", function()
      local component = C.Array({
        C.Flex(1, C.Text("A")),
        C.Flex(1, C.Text("B")),
        C.Flex(1, C.Text("C")),
      })

      C.render(0, component, { min_width = 0, max_width = 10 })

      assert.same({
        "A  B  C   ",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("max_width contraint is distributed first come first served", function()
      local component = C.Array({
        C.Text("AAAA"),
        C.Text("BBBB"),
        C.Text("CCCC"),
      })

      C.render(0, component, { max_width = 5, min_width = 0 })

      assert.same({
        "AAAAB",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("max_width is distributed last to flex children", function()
      local component = C.Array({
        C.Flex(1, C.Text("AA")),
        C.Text("BB"),
        C.Text("CC"),
      })

      C.render(0, component, { max_width = 5, min_width = 0 })

      assert.same({
        "ABBCC",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Height is max of children heights", function()
      local component = C.Stack({
        C.Array({
          C.Stack({ C.Text("A"), C.Text("B") }), -- height 2
          C.Stack({ C.Text("C") }), -- height 1
        }),
        C.Text("D"), -- should render at row 3 (after tallest child)
      })

      C.render(0, component, unconstrained())

      assert.same({
        "AC",
        "B ",
        "D ",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Width is sum of children widths (no flex)", function()
      local component = C.Array({
        C.Array({ C.Text("AA"), C.Text("BBB") }),
        C.Text("X"),
      })

      C.render(0, component, unconstrained())

      assert.same({
        "AABBBX",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Height includes flex children heights", function()
      local component = C.Stack({
        C.Array({ C.Text("A"), C.Flex(1, C.Stack({ C.Text("B"), C.Text("C") })) }),
        C.Text("D"),
      })

      C.render(0, component, { min_width = 0, max_width = 10 })

      assert.same({
        "AB        ",
        " C        ",
        "D         ",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Pads with spaces when child is shorter than sibling", function()
      local component = C.Array({
        C.Text("A"), -- height 1
        C.Stack({ C.Text("B"), C.Text("C") }), -- height 2
      })

      C.render(0, component, unconstrained())

      assert.same({
        "AB",
        " C", -- "C" should be at x=1, with space padding
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)
  end)

  describe("Stack", function()
    it("Renders children top to bottem", function()
      local component = C.Stack({
        C.Text("A"),
        C.Text("B"),
        C.Text("C"),
      })

      C.render(0, component, unconstrained())

      assert.same({
        "A",
        "B",
        "C",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Renders at the correct y offset", function()
      local component = C.Stack({
        C.Stack({
          C.Text("A"),
          C.Text("B"),
        }),
        C.Stack({
          C.Text("C"),
          C.Text("D"),
        }),
      })

      C.render(0, component, unconstrained())

      assert.same({
        "A",
        "B",
        "C",
        "D",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("Renders at the correct x offset", function()
      local component = C.Array({
        C.Stack({
          C.Text("A"),
          C.Text("B"),
        }),
        C.Stack({
          C.Text("C"),
          C.Text("D"),
        }),
      })

      C.render(0, component, unconstrained())

      assert.same({
        "AC",
        "BD",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    -- it("Passes on width constraint", function()
    --   local component = C.Stack({
    --     C.Text("AA"),
    --     C.Text("BB"),
    --     C.Text("CC"),
    --   })
    --
    --   C.render(0, component, { max_height = math.huge, max_width = 1 })
    --
    --   assert.same({
    --     "A",
    --     "B",
    --     "C",
    --   }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    -- end)

    it("Width is max of children widths", function()
      local component = C.Array({
        C.Stack({
          C.Text("A"), -- width 1
          C.Text("BBBB"), -- width 4 (max)
        }),
        C.Text("X"), -- should render at x=4
      })

      C.render(0, component, unconstrained())

      assert.same({
        "A   X",
        "BBBB ",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)
  end)

  describe("Padding", function()
    describe("isolation", function()
      it("Adds left padding", function()
        local component = C.Padding({ left = 2 }, C.Text("A"))

        C.render(0, component, unconstrained())

        assert.same({
          "  A",
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)

      it("Adds right padding", function()
        local component = C.Padding({ right = 2 }, C.Text("A"))

        C.render(0, component, unconstrained())

        assert.same({
          "A  ",
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)

      it("Adds top padding", function()
        local component = C.Padding({ top = 1 }, C.Text("A"))

        C.render(0, component, unconstrained())

        assert.same({
          " ",
          "A",
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)

      it("Adds bottom padding", function()
        local component = C.Padding({ bottom = 1 }, C.Text("A"))

        C.render(0, component, unconstrained())

        assert.same({
          "A",
          " ",
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)

      it("Adds all paddings", function()
        local component = C.Padding({ left = 1, right = 1, top = 1, bottom = 1 }, C.Text("A"))

        C.render(0, component, unconstrained())

        assert.same({
          "   ",
          " A ",
          "   ",
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)
    end)

    describe("offsets siblings", function()
      it("Left offsets in Array", function()
        local component = C.Array({
          C.Padding({ left = 2 }, C.Text("A")),
          C.Text("B"),
        })

        C.render(0, component, unconstrained())

        assert.same({
          "  AB",
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)

      it("Right offsets in Array", function()
        local component = C.Array({
          C.Padding({ right = 2 }, C.Text("A")),
          C.Text("B"),
        })

        C.render(0, component, unconstrained())

        assert.same({
          "A  B",
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)

      it("Top offsets in Stack", function()
        local component = C.Stack({
          C.Padding({ top = 1 }, C.Text("A")),
          C.Text("B"),
        })

        C.render(0, component, unconstrained())

        assert.same({
          " ",
          "A",
          "B",
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)

      it("Bottom offsets in Stack", function()
        local component = C.Stack({
          C.Padding({ bottom = 1 }, C.Text("A")),
          C.Text("B"),
        })

        C.render(0, component, unconstrained())

        assert.same({
          "A",
          " ",
          "B",
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)

      it("All paddings offset siblings", function()
        local component = C.Stack({
          C.Array({
            C.Padding({ left = 1, right = 1, top = 1, bottom = 1 }, C.Text("A")),
            C.Text("B"),
          }),
          C.Text("C"),
        })

        C.render(0, component, unconstrained())

        -- Array is top-aligned, so "B" appears on row 0 (top padding row)
        -- Canvas width is 4, so all lines are 4 chars
        assert.same({
          "   B",
          " A  ",
          "    ",
          "C   ",
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)
    end)
  end)

  describe("Highlight", function()
    before_each(function()
      vim.api.nvim_buf_clear_namespace(0, -1, 0, -1)
    end)

    ---@return table[]
    local function get_highlights(buf)
      local extmarks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })
      local result = {}
      for _, mark in ipairs(extmarks) do
        table.insert(result, {
          row = mark[2],
          col_start = mark[3],
          col_end = mark[4].end_col,
          hl_group = mark[4].hl_group,
        })
      end
      return result
    end

    it("Applies highlight to Text", function()
      local component = C.Highlight("TestHL", C.Text("ABC"))

      C.render(0, component, unconstrained())

      assert.same({
        { row = 0, col_start = 0, col_end = 3, hl_group = "TestHL" },
      }, get_highlights(0))
    end)

    it("Applies highlight to multi-line child", function()
      local component = C.Highlight("TestHL", C.Stack({
        C.Text("A"),
        C.Text("B"),
      }))

      C.render(0, component, unconstrained())

      assert.same({
        { row = 0, col_start = 0, col_end = 1, hl_group = "TestHL" },
        { row = 1, col_start = 0, col_end = 1, hl_group = "TestHL" },
      }, get_highlights(0))
    end)

    it("Nested highlights both apply", function()
      local component = C.Highlight("Outer", C.Highlight("Inner", C.Text("A")))

      C.render(0, component, unconstrained())

      assert.same({
        { row = 0, col_start = 0, col_end = 1, hl_group = "Inner" },
        { row = 0, col_start = 0, col_end = 1, hl_group = "Outer" },
      }, get_highlights(0))
    end)

    it("Highlight outside Padding includes padding", function()
      local component = C.Highlight("TestHL", C.Padding({ left = 1, right = 1 }, C.Text("A")))

      C.render(0, component, unconstrained())

      assert.same({
        { row = 0, col_start = 0, col_end = 3, hl_group = "TestHL" },
      }, get_highlights(0))
    end)

    it("Highlight inside Padding excludes padding", function()
      local component = C.Padding({ left = 1, right = 1 }, C.Highlight("TestHL", C.Text("A")))

      C.render(0, component, unconstrained())

      assert.same({
        { row = 0, col_start = 1, col_end = 2, hl_group = "TestHL" },
      }, get_highlights(0))
    end)

    it("Highlight expands with Flex", function()
      local component = C.Array({
        C.Highlight("TestHL", C.Flex(1, C.Text("A"))),
      })

      C.render(0, component, { min_width = 0, max_width = 5 })

      assert.same({
        { row = 0, col_start = 0, col_end = 5, hl_group = "TestHL" },
      }, get_highlights(0))
    end)
  end)

  describe("Actionable", function()
    local spy = require("luassert.spy")

    it("Triggers callback when cursor is on actionable", function()
      local callback = spy.new(function() end)
      local component = C.Actionable({ keybind = "x", on_triggered = callback }, C.Text("ABC"))

      C.render(0, component, unconstrained())
      vim.api.nvim_win_set_cursor(0, { 1, 1 }) -- row 1 (1-indexed), col 1
      vim.api.nvim_feedkeys("x", "x", false)

      assert.spy(callback).was.called(1)
    end)

    it("Does not trigger when cursor is outside actionable", function()
      local callback = spy.new(function() end)
      -- Layout: row 0 "AAAAA", row 1 " BBB " (actionable at cols 1-3), row 2 "CCCCC"
      local component = C.Stack({
        C.Text("AAAAA"),
        C.Array({
          C.Text(" "),
          C.Actionable({ keybind = "K", on_triggered = callback }, C.Text("BBB")),
          C.Text(" "),
        }),
        C.Text("CCCCC"),
      })

      C.render(0, component, unconstrained())

      -- Left of actionable (col 0, row 1)
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.api.nvim_feedkeys("K", "x", false)
      assert.spy(callback).was_not.called()

      -- Right of actionable (col 4, row 1)
      vim.api.nvim_win_set_cursor(0, { 2, 4 })
      vim.api.nvim_feedkeys("K", "x", false)
      assert.spy(callback).was_not.called()

      -- Above actionable (row 0)
      vim.api.nvim_win_set_cursor(0, { 1, 2 })
      vim.api.nvim_feedkeys("K", "x", false)
      assert.spy(callback).was_not.called()

      -- Below actionable (row 2)
      vim.api.nvim_win_set_cursor(0, { 3, 2 })
      vim.api.nvim_feedkeys("K", "x", false)
      assert.spy(callback).was_not.called()

      -- Verify it DOES trigger when inside
      vim.api.nvim_win_set_cursor(0, { 2, 2 })
      vim.api.nvim_feedkeys("K", "x", false)
      assert.spy(callback).was.called(1)
    end)

    it("Only triggers matching actionable with same keybind", function()
      local callback1 = spy.new(function() end)
      local callback2 = spy.new(function() end)
      local component = C.Array({
        C.Actionable({ keybind = "x", on_triggered = callback1 }, C.Text("AAA")),
        C.Actionable({ keybind = "x", on_triggered = callback2 }, C.Text("BBB")),
      })

      C.render(0, component, unconstrained())
      vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- cursor on "BBB" (starts at col 3)
      vim.api.nvim_feedkeys("x", "x", false)

      assert.spy(callback1).was_not.called()
      assert.spy(callback2).was.called(1)
    end)

    it("Re-render clears old keybinds", function()
      local callback1 = spy.new(function() end)
      local callback2 = spy.new(function() end)

      -- First render with callback1
      C.render(0, C.Actionable({ keybind = "x", on_triggered = callback1 }, C.Text("A")), unconstrained())

      -- Second render with callback2
      C.render(0, C.Actionable({ keybind = "x", on_triggered = callback2 }, C.Text("B")), unconstrained())

      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.api.nvim_feedkeys("x", "x", false)

      assert.spy(callback1).was_not.called()
      assert.spy(callback2).was.called(1)
    end)
  end)

  describe("state", function()
    local spy = require("luassert.spy")

    it("Calls listener immediately with initial value", function()
      local set_value, on_value_change = C.state(42)
      local listener = spy.new(function() end)

      on_value_change(listener)

      assert.spy(listener).was.called(1)
      assert.spy(listener).was.called_with(42)
    end)

    it("Calls listener when value changes", function()
      local set_value, on_value_change = C.state(0)
      local listener = spy.new(function() end)

      on_value_change(listener)
      listener:clear()

      set_value(1)

      assert.spy(listener).was.called(1)
      assert.spy(listener).was.called_with(1)
    end)

    it("Calls multiple listeners on change", function()
      local set_value, on_value_change = C.state("initial")
      local listener1 = spy.new(function() end)
      local listener2 = spy.new(function() end)

      on_value_change(listener1)
      on_value_change(listener2)
      listener1:clear()
      listener2:clear()

      set_value("changed")

      assert.spy(listener1).was.called_with("changed")
      assert.spy(listener2).was.called_with("changed")
    end)

    it("Works with table values", function()
      local set_value, on_value_change = C.state({ count = 0 })
      local received = nil

      on_value_change(function(v) received = v end)

      set_value({ count = 5 })

      assert.same({ count = 5 }, received)
    end)

    it("Returns unsubscribe function", function()
      local set_value, on_value_change = C.state(0)
      local listener = spy.new(function() end)

      local unsubscribe = on_value_change(listener)

      assert.is_function(unsubscribe)
    end)

    it("Unsubscribe stops future notifications", function()
      local set_value, on_value_change = C.state(0)
      local listener = spy.new(function() end)

      local unsubscribe = on_value_change(listener)
      listener:clear()

      unsubscribe()
      set_value(1)

      assert.spy(listener).was_not.called()
    end)

    it("Unsubscribe only affects the specific listener", function()
      local set_value, on_value_change = C.state(0)
      local listener1 = spy.new(function() end)
      local listener2 = spy.new(function() end)

      local unsub1 = on_value_change(listener1)
      on_value_change(listener2)
      listener1:clear()
      listener2:clear()

      unsub1()
      set_value(1)

      assert.spy(listener1).was_not.called()
      assert.spy(listener2).was.called_with(1)
    end)
  end)
end)
