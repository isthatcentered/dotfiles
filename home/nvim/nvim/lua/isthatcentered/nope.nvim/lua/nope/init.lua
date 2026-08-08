local RunConfiguration = require("nope.RunConfiguration")
local make_default_label = require("nope.make_default_label")
local Orchestrator = require("nope.Orchestrator2")
local VitestAdapter = require("nope.vitest.VitestAdapter")
local PlenaryAdapter = require("nope.plenary.PlenaryAdapter")
local ConfigurationPicker = require("nope.configuration_picker")
local strategies = require("nope.find_file_strategy")
local WindowConsumer = require("nope.consumers.WindowConsumer")
local DiagnosticsConsumer = require("nope.consumers.DiagnosticsConsumer.init")
local EventBus = require("nope.EventBus")

function table.clone(org)
  return { table.unpack(org) }
end

local strategy = strategies.LocalProjectFileStrategy.new()

local picker = ConfigurationPicker.new(strategy)

local M = {}
M.__index = M

---@type Orchestrator2|nil
local instance = nil

---@type EventBus|nil
local event_bus = nil

function M.start_run(configuration)
  assert(instance, "Nope: Must call setup method to use the plugin")
  instance:start_run(configuration)
end

function M.stop_all()
  assert(instance, "Nope: Must call setup method to use the plugin")
  instance:stop_all()
end

---@param key string
function M.stop(key)
  assert(instance, "Nope: Must call setup method to use the plugin")
  instance:stop(key)
end

---@param callback fun(event: NopeEvent)
---@return fun() unsubscribe
function M.listen(callback)
  assert(event_bus, "Nope: Must call setup method to use the plugin")
  return event_bus:listen(callback)
end

---@param configuration {adapters: FrameworkAdapter[]}
function M.setup(configuration)
  local GROUP = vim.api.nvim_create_augroup("NopeCleanup", { clear = true })
  event_bus = EventBus.Autocmd.new()
  local orchestrator = Orchestrator.new(configuration.adapters, event_bus)
  instance = orchestrator

  vim.api.nvim_create_autocmd("ExitPre", {
    group = GROUP,
    callback = function()
      orchestrator:stop_all()

      if event_bus then
        event_bus:destroy()
      end
    end,
  })
end

---@return nil
function M.run()
  local GROUP = vim.api.nvim_create_augroup("NopeCleanup", { clear = true })
  event_bus = EventBus.Autocmd.new()
  local vitest_adapter = VitestAdapter.new()
  local plenary_adapter = PlenaryAdapter.new()
  local adapters = { vitest_adapter, plenary_adapter }
  local orchestrator = Orchestrator.new(adapters, event_bus)
  instance = orchestrator
  local window_consumer = WindowConsumer.make(
    function(cb) return event_bus:listen(cb) end,
    function(cmd) event_bus:emit(cmd) end
  )
  -- DiagnosticsConsumer subscribes on construction
  DiagnosticsConsumer.new(
    function(cb) return event_bus:listen(cb) end
  )

  vim.ui.select(
    vim.tbl_map(function(adapter)
      return adapter.name
    end, adapters),
    {
      prompt = "Select an adapter",
    },
    function(selected)
      ---@type TestFrameworkAdapter?
      local adapter = vim.tbl_filter(function(adapter)
        return adapter.name == selected
      end, adapters)[1]

      if not adapter then
        return
      end

      picker:open(function(selected_config)
        if not selected_config then
          vim.notify("Aborted")
          return
        end

        local configuration = RunConfiguration.new(adapter.name, {
          configuration_path = selected_config,
          file_path = nil,
          watch = true,
          label = make_default_label(adapter.name, nil, nil, selected_config, true),
        })

        window_consumer:open()
        orchestrator:start_run(configuration)
      end, adapter.config_glob_pattern)
    end
  )

  vim.keymap.set("n", "<leader>ns", function()
    orchestrator:stop_all()
  end, { desc = "Stop all runnng tests" })

  vim.api.nvim_create_autocmd("ExitPre", {
    group = GROUP,
    callback = function()
      orchestrator:stop_all()
      window_consumer:close()

      if event_bus then
        event_bus:destroy()
      end
    end,
  })
end

return M
