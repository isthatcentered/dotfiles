---@alias VNodeType "text"|"stack"|"array"|"padding"|"extmark"|"keybind"

---@class VNode
---@field type VNodeType
---@field props table
---@field children VNode[]
---@field key string|nil

---@class ComponentInstance
---@field component fun(props: table): VNode
---@field props table
---@field key string|nil
---@field _hooks any[]
---@field _hook_index number
---@field _mounted boolean
---@field _unmount_callbacks fun()[]
---@field _children table<string, ComponentInstance>

---@class RenderOutput
---@field lines string[]
---@field extmarks ExtmarkDef[]
---@field keybinds KeybindDef[]

---@class ExtmarkDef
---@field line number -- 0-indexed
---@field col number
---@field opts table -- nvim_buf_set_extmark opts

---@class KeybindDef
---@field key string
---@field start_line number -- 1-indexed
---@field end_line number -- 1-indexed
---@field callback fun()

local M = {}

---Create a new VNode
---@param type VNodeType
---@param props table
---@param children VNode[]|nil
---@param key string|nil
---@return VNode
function M.create(type, props, children, key)
  return {
    type = type,
    props = props or {},
    children = children or {},
    key = key,
  }
end

---Create a new ComponentInstance
---@param component fun(props: table): VNode
---@param props table
---@param key string|nil
---@return ComponentInstance
function M.create_instance(component, props, key)
  return {
    component = component,
    props = props or {},
    key = key,
    _hooks = {},
    _hook_index = 1,
    _mounted = false,
    _unmount_callbacks = {},
    _children = {},
  }
end

return M
