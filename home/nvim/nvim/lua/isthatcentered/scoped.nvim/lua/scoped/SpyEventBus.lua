---@class SpyEventBus<RegistryEvent>: EventBus<A>
---@field events any[]
local SpyEventBus = {}
SpyEventBus.__index = SpyEventBus

---@return SpyEventBus
function SpyEventBus.new()
  return setmetatable({ events = {} }, SpyEventBus)
end

function SpyEventBus:subscribe()
  error("Test event bus did not expect any subscribers")
end

---@param event RegistryEvent
function SpyEventBus:emit(event)
  table.insert(self.events, event)
end

function SpyEventBus:assert_empty()
  if #self.events > 0 then
    error("Expected event bus to not have received any event")
  end
end

---@param expected integer
function SpyEventBus:assert_event_count(expected)
  if #self.events ~= expected then
    error(string.format("Expected %d events, got %d", expected, #self.events))
  end

end

---@param event RegistryEvent
function SpyEventBus:assert_received(event)
  for _, received_event in ipairs(self.events) do
    if vim.deep_equal(received_event, event) then
      return
    end
  end

  -- vim.print({"🛑events:::", self.events })
  error(string.format("Expected to receive event %s", vim.inspect(event)))
end

return SpyEventBus
