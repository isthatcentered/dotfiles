local ConfigurationPicker = require("configuration_picker")

-- Mock vim APIs for testing
_G.vim = _G.vim or {}
_G.vim.fn = _G.vim.fn or {}
_G.vim.loop = _G.vim.loop or {}
_G.vim.ui = _G.vim.ui or {}
_G.vim.log = _G.vim.log or {}
_G.vim.log.levels = { WARN = 2, ERROR = 3 }

-- Mock notification system
local notifications = {}

-- Helper function to create mock strategy
local function create_mock_strategy(files_to_return)
  return {
    find = function(self, glob)
      if type(files_to_return) == "function" then
        return files_to_return(glob)
      end
      return files_to_return or {}
    end,
  }
end

describe("ConfigurationPicker", function()
  before_each(function()
    notifications = {}
    _G.vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end
  end)

  describe("new", function()
    it("creates a new ConfigurationPicker instance with strategy", function()
      local mock_strategy = create_mock_strategy({})
      local picker = ConfigurationPicker.new(mock_strategy)
      assert.is_not_nil(picker)
      assert.equals(mock_strategy, picker.strategy)
    end)

    it("errors if no strategy provided", function()
      assert.has_error(function()
        ConfigurationPicker.new()
      end, "ConfigurationPicker requires a FindFileStrategy")
    end)

    it("errors if nil strategy provided", function()
      assert.has_error(function()
        ConfigurationPicker.new(nil)
      end, "ConfigurationPicker requires a FindFileStrategy")
    end)
  end)

  describe("open", function()
    it("delegates to strategy.find() with the filter", function()
      local find_called_with = nil
      local mock_strategy = {
        find = function(self, glob)
          find_called_with = glob
          return { "file.txt" }
        end,
      }

      _G.vim.ui.select = function(items, opts, on_choice)
        -- Simulate user selecting first item
        on_choice(items[1])
      end

      local picker = ConfigurationPicker.new(mock_strategy)
      picker:open(function(selected) end, "test*")

      assert.equals("test*", find_called_with)
    end)

    it("shows notification if no files match filter", function()
      local mock_strategy = create_mock_strategy(function(glob)
        if glob == "nonexistent*" then
          return {}
        else
          return { "fallback.txt" }
        end
      end)

      _G.vim.ui.select = function(items, opts, on_choice)
        on_choice(items[1])
      end

      local picker = ConfigurationPicker.new(mock_strategy)
      picker:open(function(selected) end, "nonexistent*")

      -- Should show notification about no matches
      assert.equals(1, #notifications)
      assert.is_true(notifications[1].msg:find("No files matching") ~= nil)
      assert.equals(_G.vim.log.levels.WARN, notifications[1].level)
    end)

    it("retries with empty filter if no files match", function()
      local find_call_count = 0
      local find_calls = {}

      local mock_strategy = {
        find = function(self, glob)
          find_call_count = find_call_count + 1
          table.insert(find_calls, glob)

          if glob == "nonexistent*" then
            return {}
          else
            return { "fallback.txt" }
          end
        end,
      }

      _G.vim.ui.select = function(items, opts, on_choice)
        on_choice(items[1])
      end

      local picker = ConfigurationPicker.new(mock_strategy)
      picker:open(function(selected) end, "nonexistent*")

      -- Should have called find twice: once with filter, once with empty
      assert.equals(2, find_call_count)
      assert.equals("nonexistent*", find_calls[1])
      assert.equals("", find_calls[2])
    end)

    it("shows error if strategy returns empty array twice", function()
      local mock_strategy = create_mock_strategy({})

      local callback_called = false
      local picker = ConfigurationPicker.new(mock_strategy)
      picker:open(function(selected)
        callback_called = true
      end, "")

      -- Should show error notification
      assert.equals(1, #notifications)
      assert.is_true(notifications[1].msg:find("No files found") ~= nil)
      assert.equals(_G.vim.log.levels.ERROR, notifications[1].level)
      assert.is_false(callback_called)
    end)

    it("shows error if no files found even after retry", function()
      local mock_strategy = create_mock_strategy({})

      local callback_called = false
      local picker = ConfigurationPicker.new(mock_strategy)
      picker:open(function(selected)
        callback_called = true
      end, "test*")

      -- Should show two notifications: warning about no match, then error
      assert.equals(2, #notifications)
      assert.is_true(notifications[1].msg:find("No files matching") ~= nil)
      assert.equals(_G.vim.log.levels.WARN, notifications[1].level)
      assert.is_true(notifications[2].msg:find("No files found") ~= nil)
      assert.equals(_G.vim.log.levels.ERROR, notifications[2].level)
      assert.is_false(callback_called)
    end)

    it("calls callback when file is selected", function()
      local mock_strategy = create_mock_strategy({ "vitest.config.js" })

      _G.vim.ui.select = function(items, opts, on_choice)
        -- Simulate user selecting first item
        on_choice(items[1])
      end

      local selected_file = nil
      local picker = ConfigurationPicker.new(mock_strategy)
      picker:open(function(selected)
        selected_file = selected
      end, "vitest*")

      assert.equals("vitest.config.js", selected_file)
    end)

    it("passes callback nil when user cancels", function()
      local mock_strategy = create_mock_strategy({ "vitest.config.js" })

      _G.vim.ui.select = function(items, opts, on_choice)
        -- Simulate user canceling (ESC)
        on_choice(nil)
      end

      local callback_received = "not_called"
      local picker = ConfigurationPicker.new(mock_strategy)
      picker:open(function(selected)
        callback_received = selected
      end, "vitest*")

      assert.is_nil(callback_received)
    end)

    it("passes all found files to vim.ui.select", function()
      local mock_strategy = create_mock_strategy({
        "vitest.config.js",
        "vitest.unit.config.js",
        "config/vitest.integration.js",
      })

      local select_items = nil
      _G.vim.ui.select = function(items, opts, on_choice)
        select_items = items
        on_choice(items[1])
      end

      local picker = ConfigurationPicker.new(mock_strategy)
      picker:open(function(selected) end, "vitest*")

      assert.equals(3, #select_items)
      assert.equals("vitest.config.js", select_items[1])
      assert.equals("vitest.unit.config.js", select_items[2])
      assert.equals("config/vitest.integration.js", select_items[3])
    end)

    it("uses correct prompt in vim.ui.select", function()
      local mock_strategy = create_mock_strategy({ "file.txt" })

      local select_opts = nil
      _G.vim.ui.select = function(items, opts, on_choice)
        select_opts = opts
        on_choice(items[1])
      end

      local picker = ConfigurationPicker.new(mock_strategy)
      picker:open(function(selected) end, "*")

      assert.equals("Select configuration file:", select_opts.prompt)
    end)
  end)
end)
