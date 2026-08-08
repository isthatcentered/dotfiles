local VNode = require('nope.ui.VNode')

---Create an Array node (keyed list container)
---@param props { items: any[], key: fun(item: any): string, render: fun(item: any, index: number): VNode }
---@return VNode
local function Array(props)
  local node = VNode.create('array', props, {})
  return node
end

return Array
