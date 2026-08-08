local VNode = require('nope.ui.VNode')

---Create a Text node (leaf component)
---@param props { text: string, hl?: string }
---@return VNode
local function Text(props)
  return VNode.create('text', props, {})
end

return Text
