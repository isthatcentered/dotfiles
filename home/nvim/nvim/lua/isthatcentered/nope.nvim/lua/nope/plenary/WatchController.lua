local Signal = require("nope.Signal")
local FileWatcher = require("nope.FileWatcher")
local debounce = require("nope.debounce")

---@class WatchController: Runner
---@field private runner Runner
---@field private file_watcher FileWatcher?
---@field private debounce_cancel fun()?
---@field private signal Signal<RunnerEvent>
---@field private unsubscribe fun()?
local M = {}
M.__index = M

---@param runner Runner
---@return WatchController
function M.new(runner)
  ---@type Signal<RunnerEvent>
  local signal = Signal.new()

  return setmetatable({
    runner = runner,
    signal = signal,
    file_watcher = nil,
    debounce_cancel = nil,
    unsubscribe = nil,
  }, M)
end

---@param listener fun(event: RunnerEvent)
---@return fun() unsubscribe
function M:listen(listener)
  return self.signal:listen(listener)
end

---@private
function M:setup_runner_listener()
  self.unsubscribe = self.runner:listen(function(event)
    -- Only forward results events, swallow process_started and process_ended
    if event.type == "results" then
      self.signal:emit(event)
    end
  end)
end

---@private
function M:teardown_runner_listener()
  if self.unsubscribe then
    self.unsubscribe()
    self.unsubscribe = nil
  end
end

---@private
function M:setup_file_watcher()
  local debounced_callback, cancel = debounce(function(_)
    self:on_files_changed()
  end, 200)

  self.debounce_cancel = cancel
  self.file_watcher = FileWatcher.new(debounced_callback)
  self.file_watcher:start()
end

---@private
function M:teardown_file_watcher()
  if self.debounce_cancel then
    self.debounce_cancel()
    self.debounce_cancel = nil
  end

  if self.file_watcher then
    self.file_watcher:stop()
    self.file_watcher = nil
  end
end

---@private
function M:on_files_changed()
  self.runner:stop()
  self.runner:start()
end

function M:start()
  self:setup_runner_listener()
  self:setup_file_watcher()

  -- Emit our own process_started (only once for entire watch session)
  self.signal:emit({ type = "process_started" })

  self.runner:start()
end

function M:stop()
  self:teardown_file_watcher()
  self:teardown_runner_listener()

  self.runner:stop()

  -- Emit process_ended (only once when watch stops)
  self.signal:emit({ type = "process_ended" })
end

return M
