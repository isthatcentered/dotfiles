---Reconciler module - diffs VNode trees and manages component instances
---
---Handles:
---  - Matching old/new nodes by key for Array diffing
---  - Tracking component instances across renders
---  - Calling mount/unmount lifecycle hooks

local VNode = require('nope.ui.VNode')
local hooks = require('nope.ui.hooks')

local M = {}

---@class ReconcileState
---@field instances table<string, ComponentInstance>
---@field schedule_rerender fun()

---Forward declaration
local reconcile_node

---Generate a stable key for a node at an index
---@param node VNode
---@param index number
---@return string
local function get_node_key(node, index)
  if node.key then
    return node.key
  end
  return tostring(index)
end

---Reconcile children arrays
---@param old_children VNode[]
---@param new_children VNode[]
---@param parent_instances table<string, ComponentInstance>
---@param state ReconcileState
---@return VNode[]
local function reconcile_children(old_children, new_children, parent_instances, state)
  old_children = old_children or {}
  new_children = new_children or {}

  -- Build map of old children by key
  local old_by_key = {}
  for i, child in ipairs(old_children) do
    if child then
      local key = get_node_key(child, i)
      old_by_key[key] = child
    end
  end

  -- Track which old keys are still used
  local used_keys = {}

  -- Reconcile each new child
  local result = {}
  for i, new_child in ipairs(new_children) do
    if new_child then
      local key = get_node_key(new_child, i)
      local old_child = old_by_key[key]
      used_keys[key] = true

      table.insert(result, reconcile_node(old_child, new_child, parent_instances, state, key))
    end
  end

  -- Unmount removed children
  for key, old_child in pairs(old_by_key) do
    if not used_keys[key] then
      local instance = parent_instances[key]
      if instance then
        hooks._run_unmount_callbacks(instance)
        -- Recursively unmount child instances
        if instance._children then
          for _, child_instance in pairs(instance._children) do
            hooks._run_unmount_callbacks(child_instance)
          end
        end
        parent_instances[key] = nil
      end
    end
  end

  return result
end

---Reconcile a single node
---@param old_node VNode|nil
---@param new_node VNode
---@param parent_instances table<string, ComponentInstance>
---@param state ReconcileState
---@param key string
---@return VNode
reconcile_node = function(old_node, new_node, parent_instances, state, key)
  if not new_node then
    return nil
  end

  -- Get or create instance for this node position
  local instance = parent_instances[key]
  if not instance then
    instance = VNode.create_instance(nil, {}, key)
    parent_instances[key] = instance
  end

  -- For Array nodes, we need special handling
  if new_node.type == 'array' then
    local items = new_node.props.items or {}
    local render_fn = new_node.props.render
    local key_fn = new_node.props.key

    if render_fn then
      -- Render each item
      local rendered_children = {}
      for i, item in ipairs(items) do
        local item_key = key_fn and key_fn(item) or tostring(i)
        local child = render_fn(item, i)
        if child then
          child.key = item_key
          table.insert(rendered_children, child)
        end
      end

      -- Get old rendered children
      local old_children = {}
      if old_node and old_node._rendered_children then
        old_children = old_node._rendered_children
      end

      -- Reconcile rendered children
      new_node._rendered_children = reconcile_children(
        old_children,
        rendered_children,
        instance._children,
        state
      )
      new_node.children = new_node._rendered_children
    end
  else
    -- Reconcile regular children
    local old_children = old_node and old_node.children or {}
    new_node.children = reconcile_children(old_children, new_node.children, instance._children, state)
  end

  return new_node
end

---Reconcile a component function call
---@param component fun(props: table): VNode
---@param props table
---@param old_instance ComponentInstance|nil
---@param state ReconcileState
---@return VNode, ComponentInstance
function M.reconcile_component(component, props, old_instance, state)
  -- Get or create instance
  local instance = old_instance
  if not instance then
    instance = VNode.create_instance(component, props, nil)
  else
    instance.props = props
  end

  -- Set hook context
  hooks._set_context(instance, state.schedule_rerender)

  -- Call component function
  local ok, vnode = pcall(component, props)

  hooks._clear_context()

  if not ok then
    error('Component render error: ' .. tostring(vnode))
  end

  -- Mark as mounted
  if not instance._mounted then
    instance._mounted = true
  end

  -- Reconcile the returned VNode
  if vnode then
    vnode = reconcile_node(
      instance._last_vnode,
      vnode,
      instance._children,
      state,
      'root'
    )
    instance._last_vnode = vnode
  end

  return vnode, instance
end

---Unmount an instance and all its children
---@param instance ComponentInstance
function M.unmount_instance(instance)
  if not instance then
    return
  end

  hooks._run_unmount_callbacks(instance)

  if instance._children then
    for _, child in pairs(instance._children) do
      M.unmount_instance(child)
    end
  end
end

return M
