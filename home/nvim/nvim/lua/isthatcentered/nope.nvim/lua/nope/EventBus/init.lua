local Signal = require("nope.Signal")

---@alias NopeEvent
---| {type: "NopeTestRunStarted", payload: {configuration: RunConfiguration, key: string}}
---| {type: "NopeTestRunResults", payload: {key: string, results: TestRunState}}
---| {type: "NopeTestRunEnded", payload: {key: string}}

---@alias NopeCommand
---| {type: "NopeStopRun", payload: {key: string}}

---@alias NopeMessage NopeEvent | NopeCommand

---@class EventBus
---@field emit fun(self: EventBus, message: NopeMessage)
---@field listen fun(self: EventBus, callback: fun(message: NopeMessage)): fun()
---@field destroy fun(self: EventBus)|nil

-- SyncEventBus: In-memory synchronous dispatch using Signal
---@class SyncEventBus: EventBus
---@field private signal Signal<NopeMessage>
local SyncEventBus = {}
SyncEventBus.__index = SyncEventBus

---@return SyncEventBus
function SyncEventBus.new()
  return setmetatable({
    signal = Signal.new(),
  }, SyncEventBus)
end

---@param message NopeMessage
function SyncEventBus:emit(message)
  self.signal:emit(message)
end

---@param callback fun(message: NopeMessage)
---@return fun() unsubscribe
function SyncEventBus:listen(callback)
  return self.signal:listen(callback)
end

function SyncEventBus:destroy()
  self.signal:off()
end

-- AutocmdEventBus: Bridges to vim autocmds
---@class AutocmdEventBus: EventBus
---@field private augroup number
local AutocmdEventBus = {}
AutocmdEventBus.__index = AutocmdEventBus

local autocmd_bus_counter = 0

---@return AutocmdEventBus
function AutocmdEventBus.new()
  autocmd_bus_counter = autocmd_bus_counter + 1
  local augroup = vim.api.nvim_create_augroup("NopeEventBus_" .. autocmd_bus_counter, { clear = true })
  return setmetatable({
    augroup = augroup,
  }, AutocmdEventBus)
end

---@param message NopeMessage
function AutocmdEventBus:emit(message)
  vim.api.nvim_exec_autocmds("User", {
    pattern = message.type,
    data = message.payload,
  })
end

---@param callback fun(message: NopeMessage)
---@return fun() unsubscribe
function AutocmdEventBus:listen(callback)
  local patterns = { "NopeTestRunStarted", "NopeTestRunResults", "NopeTestRunEnded", "NopeStopRun" }
  local autocmd_id = vim.api.nvim_create_autocmd("User", {
    group = self.augroup,
    pattern = patterns,
    callback = function(args)
      callback({ type = args.match, payload = args.data })
    end,
  })
  return function()
    pcall(vim.api.nvim_del_autocmd, autocmd_id)
  end
end

function AutocmdEventBus:destroy()
  pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
end

return {
  Sync = { new = SyncEventBus.new },
  Autocmd = { new = AutocmdEventBus.new },
}
