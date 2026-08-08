---@class Notifications
---@field lists {[ListIdV2]: string} Record<ListId, ListName>
---@field notify fun(message: string)
local M = {}
M.__index = M

---@param params {event_bus: EventBus<RegistryEvent>, notify: fun(message:string)}
---@return Notifications
function M.new(params)
  local self = setmetatable({ lists = {}, notify = params.notify }, M)

  params.event_bus:subscribe(function(event)
    -- vim.print(event)
    local list_name = self.lists[event.list_id] or "Default"

    if event.type == "list_created" then
      self.lists[event.list_id] = event.list_name

      params.notify(
        string.format('List "%s" created', event.list_name) --
      )
    end

    if event.type == "list_bound" then
      params.notify(
        string.format('List "%s" bound to current window', list_name) --
      )
    end

    if event.type == "bookmark_added" then
      local file_name = vim.fs.basename(event.path)

      params.notify(
        string.format('File "%s" added to list "%s"', file_name, list_name) --
      )
    end

    if event.type == "bookmark_removed" then
      local file_name = vim.fs.basename(event.path)

      params.notify(
        string.format('File "%s" removed from list "%s"', file_name, list_name) --
      )
    end
  end)

  return self
end

return M
