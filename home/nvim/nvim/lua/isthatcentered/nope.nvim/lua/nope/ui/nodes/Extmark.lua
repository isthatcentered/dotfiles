local VNode = require('nope.ui.VNode')

---Create an Extmark node (adds extmark to child)
---@param props { sign_text?: string, sign_hl?: string, virt_text?: table, virt_text_pos?: string, hl_group?: string }
---@param children VNode[]
---@return VNode
local function Extmark(props, children)
  -- Filter out nil children
  local filtered = {}
  for _, child in ipairs(children or {}) do
    if child ~= nil then
      table.insert(filtered, child)
    end
  end
  return VNode.create('extmark', props or {}, filtered)
end

return Extmark
