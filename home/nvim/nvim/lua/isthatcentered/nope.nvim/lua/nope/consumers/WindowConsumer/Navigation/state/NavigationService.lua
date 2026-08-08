local TreeModel = require("nope.consumers.WindowConsumer.Navigation.data.TreeModel")

---@class TabInfo
---@field key string
---@field label string
---@field status "running"|"done"|"cancelled"
---@field has_failures boolean

---@class WindowConsumerState
---@field tabs TabInfo[]
---@field active_tab_key string|nil
---@field nodes TreeNode[]
---@field selected_id string|nil
---@field showing_help boolean
---@field filter_active boolean
---@field selected_node TreeNode|nil
---@field summary {total: number, passed: number, failed: number, skipped: number}|nil
---@field duration_ms number|nil
---@field scope_filter_id string|nil
---@field scope_breadcrumb string[]|nil

---@class ServiceRunState
---@field key string
---@field label string
---@field status "running"|"done"|"cancelled"
---@field has_failures boolean
---@field filter_active boolean
---@field scope_filter_id string|nil
---@field tree_root TreeNode|nil
---@field nodes TreeNode[]
---@field filtered_nodes TreeNode[]
---@field id_to_line table<string, number>
---@field selected_id string|nil
---@field summary {total: number, passed: number, failed: number, skipped: number}|nil
---@field duration_ms number|nil

---@class NavigationService
---@field private runs table<string, ServiceRunState>
---@field private run_order string[]
---@field private active_run_key string|nil
---@field private showing_help boolean
---@field private subscribers fun(state: WindowConsumerState)[]
---@field private send_command fun(cmd: NopeCommand)
local Service = {}
Service.__index = Service

---@param send_command fun(cmd: NopeCommand)
---@return NavigationService
function Service.new(send_command)
  local self = setmetatable({
    runs = {},
    run_order = {},
    active_run_key = nil,
    showing_help = false,
    subscribers = {},
    send_command = send_command,
  }, Service)
  return self
end

---@private
---@return ServiceRunState|nil
function Service:_get_active_run()
  if not self.active_run_key then
    return nil
  end
  return self.runs[self.active_run_key]
end

---@return WindowConsumerState
function Service:get_state()
  local tabs = {}
  for _, key in ipairs(self.run_order) do
    local run = self.runs[key]
    table.insert(tabs, {
      key = run.key,
      label = run.label,
      status = run.status,
      has_failures = run.has_failures,
    })
  end

  local active_run = self:_get_active_run()
  local filtered_nodes = active_run and active_run.filtered_nodes or {}
  local raw_selected_id = active_run and active_run.selected_id or nil
  local filter_active = active_run and active_run.filter_active or false
  local scope_filter_id = active_run and active_run.scope_filter_id or nil

  -- Compute effective selection: use raw if in view, otherwise first visible
  local effective_selected_id = nil
  if raw_selected_id then
    for _, node in ipairs(filtered_nodes) do
      if node.id == raw_selected_id then
        effective_selected_id = raw_selected_id
        break
      end
    end
  end
  if not effective_selected_id and #filtered_nodes > 0 then
    effective_selected_id = filtered_nodes[1].id
  end

  -- Compute breadcrumb for UI display
  local scope_breadcrumb = nil
  if scope_filter_id and active_run and active_run.tree_root then
    scope_breadcrumb = TreeModel.get_breadcrumb(active_run.tree_root, scope_filter_id)
  end

  -- Find selected_node by effective selection
  local selected_node = nil
  if effective_selected_id and active_run and active_run.tree_root then
    selected_node = TreeModel.find_by_id(active_run.tree_root, effective_selected_id)
  end

  return {
    tabs = tabs,
    active_tab_key = self.active_run_key,
    nodes = filtered_nodes,
    selected_id = effective_selected_id,
    showing_help = self.showing_help,
    filter_active = filter_active,
    selected_node = selected_node,
    summary = active_run and active_run.summary or nil,
    duration_ms = active_run and active_run.duration_ms or nil,
    scope_filter_id = scope_filter_id,
    scope_breadcrumb = scope_breadcrumb,
  }
end

---@private
function Service:_notify()
  local state = self:get_state()
  for _, cb in ipairs(self.subscribers) do
    cb(state)
  end
end

---@param cb fun(state: WindowConsumerState)
---@return fun() unsubscribe
function Service:subscribe(cb)
  table.insert(self.subscribers, cb)
  cb(self:get_state())

  return function()
    for i, subscriber in ipairs(self.subscribers) do
      if subscriber == cb then
        table.remove(self.subscribers, i)
        return
      end
    end
  end
end

---@private
---@param key string
---@param configuration table|nil
---@return ServiceRunState
function Service:_get_or_create_run(key, configuration)
  local run = self.runs[key]
  if run then
    return run
  end

  run = {
    key = key,
    label = configuration and configuration.label or key:sub(1, 8),
    status = "running",
    has_failures = false,
    filter_active = false,
    scope_filter_id = nil,
    tree_root = nil,
    nodes = {},
    filtered_nodes = {},
    id_to_line = {},
    selected_id = nil,
  }
  self.runs[key] = run
  table.insert(self.run_order, key)

  return run
end

---@private
---@param run ServiceRunState
function Service:_recompute_filtered_view(run)
  local working_root = run.tree_root
  if run.scope_filter_id and working_root then
    -- Strict: if scoped node not found, working_root becomes nil → empty view
    working_root = TreeModel.filter_by_scope(working_root, run.scope_filter_id)
  end
  if run.filter_active and working_root then
    working_root = TreeModel.filter_failures(working_root)
  end
  run.filtered_nodes = working_root and TreeModel.flatten(working_root) or {}
  -- Note: selected_id is NOT cleared when not in filtered view.
  -- get_state() computes effective selection for UI.
end

---@private
---@param key string
---@param configuration table|nil
function Service:_on_run_started(key, configuration)
  local run = self:_get_or_create_run(key, configuration)
  run.status = "running"

  if configuration and configuration.label then
    run.label = configuration.label
  end

  if not self.active_run_key then
    self.active_run_key = key
  end

  self:_notify()
end

---@private
---@param key string
function Service:_on_run_ended(key)
  local run = self.runs[key]
  if run then
    run.status = "done"
    self:_notify()
  end
end

---@private
---@param key string
---@param results table TestRunState
function Service:_on_results(key, results)
  local run = self:_get_or_create_run(key, nil)

  -- Build tree and flatten
  local root = TreeModel.build(results)
  local nodes, id_to_line = TreeModel.flatten(root)

  run.tree_root = root
  run.nodes = nodes
  run.id_to_line = id_to_line
  run.has_failures = (results.summary and results.summary.failed > 0) or false
  run.summary = results.summary
  run.duration_ms = results.duration_ms

  -- Auto-select first node if none selected (before filtering)
  if not run.selected_id and #nodes > 0 then
    run.selected_id = nodes[1].id
  end

  -- Recompute filtered view and validate selection
  self:_recompute_filtered_view(run)

  -- Auto-activate if no active run
  if not self.active_run_key then
    self.active_run_key = key
  end

  self:_notify()
end

---@param event table
function Service:handle_event(event)
  if event.type == "NopeTestRunStarted" then
    local key = event.payload.key
    if key then
      self:_on_run_started(key, event.payload.configuration)
    end
  elseif event.type == "NopeTestRunEnded" then
    local key = event.payload.key
    if key then
      self:_on_run_ended(key)
    end
  elseif event.type == "NopeTestRunResults" then
    local key = event.payload.key
    if key then
      self:_on_results(key, event.payload.results)
    end
  end
end

---@param delta number +1 for next, -1 for previous
function Service:switch_tab(delta)
  if #self.run_order < 2 then
    return
  end

  local current_idx = 1
  for i, key in ipairs(self.run_order) do
    if key == self.active_run_key then
      current_idx = i
      break
    end
  end

  local new_idx = ((current_idx - 1 + delta) % #self.run_order) + 1
  self.active_run_key = self.run_order[new_idx]
  self:_notify()
end

---@param index number 1-based tab index
function Service:switch_to_tab(index)
  if index < 1 or index > #self.run_order then
    return
  end

  self.active_run_key = self.run_order[index]
  self:_notify()
end

function Service:close_tab()
  if not self.active_run_key then
    return
  end

  local key_to_close = self.active_run_key

  -- Send stop command
  self.send_command({
    type = "NopeStopRun",
    payload = { key = key_to_close },
  })

  -- Find current index
  local current_idx = 1
  for i, key in ipairs(self.run_order) do
    if key == key_to_close then
      current_idx = i
      break
    end
  end

  -- Remove from runs and run_order
  self.runs[key_to_close] = nil
  table.remove(self.run_order, current_idx)

  -- Switch to another tab or clear
  if #self.run_order == 0 then
    self.active_run_key = nil
  else
    local new_idx = math.min(current_idx, #self.run_order)
    self.active_run_key = self.run_order[new_idx]
  end

  self:_notify()
end

function Service:stop_run()
  if not self.active_run_key then
    return
  end
  self.send_command({
    type = "NopeStopRun",
    payload = { key = self.active_run_key },
  })
end

---@param delta number +1 for next, -1 for previous
function Service:move_selection(delta)
  local run = self:_get_active_run()
  if not run then
    return
  end

  -- Use filtered nodes from get_state
  local state = self:get_state()
  local nodes = state.nodes
  if #nodes == 0 then
    return
  end

  -- Find current index in visible nodes
  local current_idx = 1
  if run.selected_id then
    for i, node in ipairs(nodes) do
      if node.id == run.selected_id then
        current_idx = i
        break
      end
    end
  end

  local new_idx = current_idx + delta

  -- Wrap at boundaries
  if new_idx < 1 then
    new_idx = #nodes
  elseif new_idx > #nodes then
    new_idx = 1
  end

  run.selected_id = nodes[new_idx].id
  self:_notify()
end

function Service:toggle_help()
  self.showing_help = not self.showing_help
  self:_notify()
end

function Service:toggle_failures_filter()
  local run = self:_get_active_run()
  if not run then
    return
  end

  run.filter_active = not run.filter_active
  self:_recompute_filtered_view(run)
  self:_notify()
end

---@param scope_id string
function Service:set_scope_filter(scope_id)
  local run = self:_get_active_run()
  if not run then
    return
  end
  run.scope_filter_id = scope_id
  self:_recompute_filtered_view(run)
  self:_notify()
end

function Service:clear_scope_filter()
  local run = self:_get_active_run()
  if not run then
    return
  end
  run.scope_filter_id = nil
  self:_recompute_filtered_view(run)
  self:_notify()
end

---@param scope_id string
function Service:toggle_scope_filter(scope_id)
  local run = self:_get_active_run()
  if not run then
    return
  end
  if run.scope_filter_id == scope_id then
    run.scope_filter_id = nil
  else
    run.scope_filter_id = scope_id
  end
  self:_recompute_filtered_view(run)
  self:_notify()
end

return Service
