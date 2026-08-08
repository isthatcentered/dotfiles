local Registry = require("scoped.v2.Registry")
local utils = require("scoped.utils")
local spy = require("luassert.spy")
local EventBus = require("scoped.EventBus")
local EventLog = require("scoped.EventLog")
local test_utils = require("scoped.test_utils")
local SpyEventBus = require("scoped.SpyEventBus")
local Notifications = require("scoped.v2.Notifications")
local FIXTURE_FILES = {
  a = "/Users/edouardpenin/Test/nvim/scoped.nvim/lua/scoped/fixtures/a.txt",
  b = "/Users/edouardpenin/Test/nvim/scoped.nvim/lua/scoped/fixtures/b.txt",
  c = "/Users/edouardpenin/Test/nvim/scoped.nvim/lua/scoped/fixtures/c.txt",
  d = "/Users/edouardpenin/Test/nvim/scoped.nvim/lua/scoped/fixtures/d.txt",
}

local function random_valid_file_path()
  local paths = vim.tbl_values(FIXTURE_FILES)
  return paths[math.random(#paths)]
end

function _describe(name, fn) end

function _it(name, fn) end

describe("Notifications", function()
  it("list_created", function()
    local last_sent
    local context = { window_id = vim.api.nvim_get_current_win() }
    local event_bus = EventBus.new()
    local registry = Registry.new({ event_bus = event_bus })
    Notifications.new({
      event_bus = event_bus,
      notify = function(msg)
        last_sent = msg
      end,
    })

    registry:create_list("list_id", "list_name")

    assert.same(last_sent, string.format('List "list_name" created'))
  end)

  describe("file_added", function()
    it("File added to default list", function()
      local last_sent
      local context = { window_id = vim.api.nvim_get_current_win() }
      local event_bus = EventBus.new()
      local registry = Registry.new({ event_bus = event_bus })
      Notifications.new({
        event_bus = event_bus,
        notify = function(msg)
          last_sent = msg
        end,
      })

      registry:add_file_to_current_list(FIXTURE_FILES.a, context)

      assert.same(last_sent, string.format('File "%s" added to list "%s"', "a.txt", "Default"))
    end)

    it("File added to custom list", function()
      local last_sent
      local context = { window_id = vim.api.nvim_get_current_win() }
      local event_bus = EventBus.new()
      local registry = Registry.new({ event_bus = event_bus })
      Notifications.new({
        event_bus = event_bus,
        notify = function(msg)
          last_sent = msg
        end,
      })
      registry:create_list("list_id", "list_name")
      registry:bind_list_to_window("list_id", context)

      registry:add_file_to_current_list(FIXTURE_FILES.a, context)

      assert.same(last_sent, string.format('File "%s" added to list "%s"', "a.txt", "list_name"))
    end)
  end)

  describe("file_removed", function()
    it("File removed from default list", function()
      local last_sent
      local context = { window_id = vim.api.nvim_get_current_win() }
      local event_bus = EventBus.new()
      local registry = Registry.new({ event_bus = event_bus })
      Notifications.new({
        event_bus = event_bus,
        notify = function(msg)
          last_sent = msg
        end,
      })

      registry:add_file_to_current_list(FIXTURE_FILES.a, context)
      registry:remove_file_from_current_list(FIXTURE_FILES.a, context)

      assert.same(string.format('File "%s" removed from list "%s"', "a.txt", "Default"), last_sent)
    end)

    it("File removed from custom list", function()
      local last_sent
      local context = { window_id = vim.api.nvim_get_current_win() }
      local event_bus = EventBus.new()
      local registry = Registry.new({ event_bus = event_bus })
      Notifications.new({
        event_bus = event_bus,
        notify = function(msg)
          last_sent = msg
        end,
      })
      registry:create_list("list_id", "list_name")
      registry:bind_list_to_window("list_id", context)

      registry:add_file_to_current_list(FIXTURE_FILES.a, context)
      registry:remove_file_from_current_list(FIXTURE_FILES.a, context)

      assert.same(string.format('File "%s" removed from list "%s"', "a.txt", "list_name"), last_sent)
    end)
  end)

  it("list_bound", function()
    local last_sent
    local context = { window_id = vim.api.nvim_get_current_win() }
    local event_bus = EventBus.new()
    local registry = Registry.new({ event_bus = event_bus })
    Notifications.new({
      event_bus = event_bus,
      notify = function(msg)
        last_sent = msg
      end,
    })

    registry:create_list("list_id", "list_name")
    registry:bind_list_to_window("list_id", context)

    assert.same(last_sent, string.format('List "list_name" bound to current window'))
  end)
end)
