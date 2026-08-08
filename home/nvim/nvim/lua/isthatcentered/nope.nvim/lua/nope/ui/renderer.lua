---Renderer module - flattens VNode tree to buffer output
---
---Converts VNode tree into:
---  - lines: string[] for nvim_buf_set_lines
---  - extmarks: ExtmarkDef[] for nvim_buf_set_extmark
---  - keybinds: KeybindDef[] for buffer keymaps

local M = {}

---@class RenderContext
---@field lines string[]
---@field extmarks ExtmarkDef[]
---@field keybinds KeybindDef[]
---@field current_line number -- 1-indexed
---@field left_padding number -- accumulated left padding

---Create a new render context
---@return RenderContext
local function create_context()
  return {
    lines = {},
    extmarks = {},
    keybinds = {},
    current_line = 1,
    left_padding = 0,
  }
end

---Add a line to the context
---@param ctx RenderContext
---@param text string
---@param hl string|nil
local function add_line(ctx, text, hl)
  local padded_text = string.rep(' ', ctx.left_padding) .. text
  table.insert(ctx.lines, padded_text)

  if hl then
    table.insert(ctx.extmarks, {
      line = ctx.current_line - 1, -- 0-indexed
      col = 0,
      opts = {
        end_col = #padded_text,
        hl_group = hl,
      },
    })
  end

  ctx.current_line = ctx.current_line + 1
end

---Add empty lines
---@param ctx RenderContext
---@param count number
local function add_empty_lines(ctx, count)
  for _ = 1, count do
    table.insert(ctx.lines, '')
    ctx.current_line = ctx.current_line + 1
  end
end

---Forward declaration
local render_node

---Render a Text node
---@param node VNode
---@param ctx RenderContext
local function render_text(node, ctx)
  add_line(ctx, node.props.text or '', node.props.hl)
end

---Render a Stack node
---@param node VNode
---@param ctx RenderContext
local function render_stack(node, ctx)
  for _, child in ipairs(node.children) do
    render_node(child, ctx)
  end
end

---Render an Array node
---@param node VNode
---@param ctx RenderContext
local function render_array(node, ctx)
  local items = node.props.items or {}
  local render_fn = node.props.render
  local key_fn = node.props.key

  if not render_fn then
    return
  end

  for i, item in ipairs(items) do
    local child = render_fn(item, i)
    if child then
      if key_fn then
        child.key = key_fn(item)
      end
      render_node(child, ctx)
    end
  end
end

---Render a Padding node
---@param node VNode
---@param ctx RenderContext
local function render_padding(node, ctx)
  local top = node.props.top or 0
  local bottom = node.props.bottom or 0
  local left = node.props.left or 0

  -- Add top padding
  add_empty_lines(ctx, top)

  -- Render children with left padding
  local prev_padding = ctx.left_padding
  ctx.left_padding = ctx.left_padding + left

  for _, child in ipairs(node.children) do
    render_node(child, ctx)
  end

  ctx.left_padding = prev_padding

  -- Add bottom padding
  add_empty_lines(ctx, bottom)
end

---Render an Extmark node
---@param node VNode
---@param ctx RenderContext
local function render_extmark(node, ctx)
  local start_line = ctx.current_line

  -- Render children first
  for _, child in ipairs(node.children) do
    render_node(child, ctx)
  end

  local end_line = ctx.current_line - 1

  -- Add extmark for each line in range
  if start_line <= end_line then
    local opts = {}

    if node.props.sign_text then
      opts.sign_text = node.props.sign_text
    end
    if node.props.sign_hl then
      opts.sign_hl_group = node.props.sign_hl
    end
    if node.props.virt_text then
      opts.virt_text = node.props.virt_text
    end
    if node.props.virt_text_pos then
      opts.virt_text_pos = node.props.virt_text_pos
    end
    if node.props.hl_group then
      opts.hl_group = node.props.hl_group
      opts.end_col = #(ctx.lines[start_line] or '')
    end

    -- Apply extmark to first line of children
    table.insert(ctx.extmarks, {
      line = start_line - 1, -- 0-indexed
      col = 0,
      opts = opts,
    })
  end
end

---Render a Keybind node
---@param node VNode
---@param ctx RenderContext
local function render_keybind(node, ctx)
  local start_line = ctx.current_line

  -- Render children first
  for _, child in ipairs(node.children) do
    render_node(child, ctx)
  end

  local end_line = ctx.current_line - 1

  -- Register keybind for line range
  if node.props.key and node.props.on_press and start_line <= end_line then
    table.insert(ctx.keybinds, {
      key = node.props.key,
      start_line = start_line,
      end_line = end_line,
      callback = node.props.on_press,
    })
  end
end

---Render a VNode to the context
---@param node VNode
---@param ctx RenderContext
render_node = function(node, ctx)
  if not node then
    return
  end

  local type = node.type

  if type == 'text' then
    render_text(node, ctx)
  elseif type == 'stack' then
    render_stack(node, ctx)
  elseif type == 'array' then
    render_array(node, ctx)
  elseif type == 'padding' then
    render_padding(node, ctx)
  elseif type == 'extmark' then
    render_extmark(node, ctx)
  elseif type == 'keybind' then
    render_keybind(node, ctx)
  end
end

---Render a VNode tree to RenderOutput
---@param root VNode
---@return RenderOutput
function M.render(root)
  local ctx = create_context()
  render_node(root, ctx)
  return {
    lines = ctx.lines,
    extmarks = ctx.extmarks,
    keybinds = ctx.keybinds,
  }
end

---Apply RenderOutput to a buffer
---@param buf number
---@param output RenderOutput
---@param ns_id number
function M.apply(buf, output, ns_id)
  -- Set lines
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, output.lines)
  vim.bo[buf].modifiable = false

  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

  -- Apply extmarks
  for _, em in ipairs(output.extmarks) do
    vim.api.nvim_buf_set_extmark(buf, ns_id, em.line, em.col, em.opts)
  end
end

---Apply keybinds to a buffer
---@param buf number
---@param keybinds KeybindDef[]
---@param existing_keys table<string, boolean>
function M.apply_keybinds(buf, keybinds, existing_keys)
  -- Group keybinds by key
  local keybinds_by_key = {}
  for _, kb in ipairs(keybinds) do
    keybinds_by_key[kb.key] = keybinds_by_key[kb.key] or {}
    table.insert(keybinds_by_key[kb.key], kb)
  end

  -- Remove old keybinds that are no longer used
  for key in pairs(existing_keys) do
    if not keybinds_by_key[key] then
      pcall(vim.keymap.del, 'n', key, { buffer = buf })
      existing_keys[key] = nil
    end
  end

  -- Set up keybinds
  for key, bindings in pairs(keybinds_by_key) do
    vim.keymap.set('n', key, function()
      local line = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed
      for _, kb in ipairs(bindings) do
        if line >= kb.start_line and line <= kb.end_line then
          kb.callback()
          return
        end
      end
    end, { buffer = buf, nowait = true })
    existing_keys[key] = true
  end
end

return M
