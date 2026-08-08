local VNode = require('nope.ui.VNode')

---Create a Padding node (adds space around child)
---@param props { top?: number, bottom?: number, left?: number }
---@param children VNode[]
---@return VNode
local function Padding(props, children)
  -- Filter out nil children
  local filtered = {}
  for _, child in ipairs(children or {}) do
    if child ~= nil then
      table.insert(filtered, child)
    end
  end
  return VNode.create('padding', props or {}, filtered)
end

return Padding
