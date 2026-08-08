local VNode = require('nope.ui.VNode')

---Create a Keybind node (attaches keymap to child's line range)
---@param props { key: string, on_press: fun() }
---@param children VNode[]
---@return VNode
local function Keybind(props, children)
  -- Filter out nil children
  local filtered = {}
  for _, child in ipairs(children or {}) do
    if child ~= nil then
      table.insert(filtered, child)
    end
  end
  return VNode.create('keybind', props or {}, filtered)
end

return Keybind
