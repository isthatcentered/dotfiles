---@class EventLog<A>: {events: A[]}
local EventLog = {}
EventLog.__index = EventLog

---@generic A
---@return EventLog<A>
function EventLog.new()
  local self = setmetatable({ events = {} }, EventLog)
  return self
end

---@generic A
---@param self EventLog<A>
---@param event A
function EventLog:record(event)
  table.insert(self.events, event)
end

---@generic A
---@param self EventLog<A>
---@return fun(event: A): nil
function EventLog:listen()
  return function(event)
    table.insert(self.events, event)
  end
end

---@generic A
---@param self EventLog<A>
---@param event_type string
---@param count number|nil
function EventLog:has_received_event_type(event_type, count)
  local received_count = 0
  for _, event in ipairs(self.events) do
    if event.type == event_type then
      received_count = received_count + 1
    end
  end

  if count then
    assert(
      received_count == count,
      string.format("Expected %d events of type '%s', but received %d", count, event_type, received_count)
    )
  else
    assert(received_count > 0, string.format("Expected to receive event type '%s', but received none", event_type))
  end
end

---@generic A
---@param self EventLog<A>
---@param event A
function EventLog:has_received(event)
  for _, received_event in ipairs(self.events) do
    if vim.deep_equal(received_event, event) then
      return
    end
  end

  error(string.format("Expected to receive event %s", vim.inspect(event)))
end

function EventLog:assert_empty()
  if #self.events > 0 then
    error('Expected event log to be empty')
  end
end

return EventLog
