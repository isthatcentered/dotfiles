local VNode = require('nope.ui.VNode')

---Create a Stack node (vertical container)
---@param props table
---@param children VNode[]
---@return VNode
local function Stack(props, children)
  -- Filter out nil/false children
  -- Note: Lua tables with holes have undefined length, so callers should
  -- use vim.tbl_filter or build tables without holes for predictable behavior
  local filtered = {}
  if children then
    for i = 1, (children.n or #children) do
      local child = children[i]
      if child then
        table.insert(filtered, child)
      end
    end
  end
  return VNode.create('stack', props or {}, filtered)
end

return Stack
