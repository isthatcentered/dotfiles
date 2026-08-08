---@class C.BoxConstraints
---@field max_width integer

---@class C.Size
---@field width integer
---@field height integer

---@class C.Offset
---@field x integer
---@field y integer

---@class C.Highlight
---@field row integer
---@field col_start integer
---@field col_end integer
---@field hl_group string

---@class C.PaintContext
---@field lines string[]
---@field highlights C.Highlight[]

---@class C.RenderObject
---@field size C.Size
---@field children C.RenderObject[]
---@field layout fun(self, constraints: C.BoxConstraints)
---@field paint fun(self, context: C.PaintContext, offset: C.Offset)

---@class C.Widget
---@field create_render_object fun(self): C.RenderObject

local M = {}
local ns_id = vim.api.nvim_create_namespace("nope.ui2")
local registered_keybinds = {} -- [buffer_id] = { keybind1, keybind2, ... }

---@param content string
---@return C.Widget
function M.Text(content)
  return {
    create_render_object = function()
      local render_object = {
        children = {},
        size = { width = 0, height = 0 },
      }

      function render_object:layout(constraints)
        self.size = {
          width = math.max(constraints.min_width, math.min(constraints.max_width, #content)),
          height = 1,
        }
      end

      function render_object:paint(context, offset)
        local line_number = offset.y + 1
        local text = string.sub(content, 1, self.size.width)

        -- Overwrite chars at position (canvas is pre-filled)
        local line = context.lines[line_number]
        local before = string.sub(line, 1, offset.x)
        local after = string.sub(line, offset.x + #text + 1)
        context.lines[line_number] = before .. text .. after
      end

      return render_object
    end,
  }
end

---@param weight integer
---@param child C.Widget
---@return C.Widget
function M.Flex(weight, child)
  return {
    create_render_object = function()
      local child_render_object = child:create_render_object()
      local render_object = {
        size = { width = 0, height = 0 },
        children = { child_render_object },
        flex_weight = weight,
      }

      function render_object:layout(constraint)
        for _, c in ipairs(self.children) do
          c:layout(constraint)
          self.size.width = math.max(self.size.width, c.size.width)
          self.size.height = math.max(self.size.height, c.size.height)
        end
      end

      function render_object:paint(context, offset)
        for _, child in ipairs(self.children) do
          child:paint(context, offset)
        end
      end

      return render_object
    end,
  }
end

---@class C.PaddingOptions
---@field left? integer
---@field right? integer
---@field top? integer
---@field bottom? integer

---@param options C.PaddingOptions
---@param child C.Widget
---@return C.Widget
function M.Padding(options, child)
  local left = options.left or 0
  local right = options.right or 0
  local top = options.top or 0
  local bottom = options.bottom or 0

  return {
    create_render_object = function()
      local child_render_object = child:create_render_object()
      local render_object = {
        size = { width = 0, height = 0 },
        children = { child_render_object },
      }

      function render_object:layout(constraint)
        local child_constraint = {
          max_width = math.max(0, constraint.max_width - left - right),
          min_width = math.max(0, constraint.min_width - left - right),
        }
        child_render_object:layout(child_constraint)

        self.size.width = child_render_object.size.width + left + right
        self.size.height = child_render_object.size.height + top + bottom
      end

      function render_object:paint(context, offset)
        -- Just offset the child (canvas is pre-filled)
        child_render_object:paint(context, {
          x = offset.x + left,
          y = offset.y + top,
        })
      end

      return render_object
    end,
  }
end

---@param hl_group string
---@param child C.Widget
---@return C.Widget
function M.Highlight(hl_group, child)
  return {
    create_render_object = function()
      local child_ro = child:create_render_object()
      local ro = {
        size = { width = 0, height = 0 },
        children = { child_ro },
        hl_group = hl_group,
        flex_weight = child_ro.flex_weight, -- pass through for Array
      }

      function ro:layout(constraint)
        child_ro:layout(constraint)
        self.size = { width = child_ro.size.width, height = child_ro.size.height }
      end

      function ro:paint(context, offset)
        child_ro:paint(context, offset)
        for row = 0, self.size.height - 1 do
          table.insert(context.highlights, {
            row = offset.y + row,
            col_start = offset.x,
            col_end = offset.x + self.size.width,
            hl_group = self.hl_group,
          })
        end
      end

      return ro
    end,
  }
end

---@class C.ActionableProps
---@field keybind string
---@field on_triggered fun()

---@param opts C.ActionableProps
---@param child C.Widget
---@return C.Widget
function M.Actionable(opts, child)
  return {
    create_render_object = function()
      local child_ro = child:create_render_object()
      local ro = {
        size = { width = 0, height = 0 },
        children = { child_ro },
        flex_weight = child_ro.flex_weight,
        keybind = opts.keybind,
        on_triggered = opts.on_triggered,
      }

      function ro:layout(constraint)
        child_ro:layout(constraint)
        self.size = { width = child_ro.size.width, height = child_ro.size.height }
      end

      function ro:paint(context, offset)
        child_ro:paint(context, offset)
        context.actionables[self.keybind] = context.actionables[self.keybind] or {}
        for row = 0, self.size.height - 1 do
          table.insert(context.actionables[self.keybind], {
            row = offset.y + row,
            col_start = offset.x,
            col_end = offset.x + self.size.width,
            on_triggered = self.on_triggered,
          })
        end
      end

      return ro
    end,
  }
end

---@param children C.Widget[]
---@return C.Widget
function M.Array(children)
  return {
    create_render_object = function()
      local children_render_objects = {}
      for _, child in ipairs(children) do
        table.insert(children_render_objects, child:create_render_object())
      end

      local render_object = {
        children = children_render_objects,
        size = {
          width = 0,
          height = 0,
        },
      }

      function render_object:layout(constraint)
        local fixed_width_children = {}
        local flex_children = {}
        local total_flex_weight = 0

        for _, child in ipairs(self.children) do
          if child.flex_weight then
            table.insert(flex_children, child)
            total_flex_weight = total_flex_weight + child.flex_weight
          else
            table.insert(fixed_width_children, child)
          end
        end

        local max_width_left = constraint.max_width
        for _, child in ipairs(fixed_width_children) do
          child:layout({
            max_width = max_width_left,
            min_width = constraint.min_width,
          })
          self.size.width = self.size.width + child.size.width
          self.size.height = math.max(self.size.height, child.size.height)
          max_width_left = max_width_left - child.size.width
        end

        local total_available_flex_width = constraint.max_width - self.size.width
        local flex_width_remaining = constraint.max_width - self.size.width
        for _, child in ipairs(flex_children) do
          local is_last = _ == #flex_children
          local width = is_last and flex_width_remaining
            or math.floor(total_available_flex_width * (child.flex_weight / total_flex_weight))

          child:layout({
            min_width = width,
            max_width = width,
          })

          self.size.height = math.max(self.size.height, child.size.height)
          flex_width_remaining = flex_width_remaining - width
        end

        if #flex_children > 0 then
          self.size.width = constraint.max_width
        end
      end

      function render_object:paint(context, offset)
        local x_offset = offset.x

        for _, child in ipairs(self.children) do
          child:paint(context, { x = x_offset, y = offset.y })
          x_offset = x_offset + child.size.width
        end
      end

      return render_object
    end,
  }
end

---Center child horizontally within available width
---@param child C.Widget
---@return C.Widget
function M.Center(child)
  return {
    create_render_object = function()
      local child_ro = child:create_render_object()
      local render_object = {
        children = { child_ro },
        size = { width = 0, height = 0 },
      }

      function render_object:layout(constraint)
        child_ro:layout({
          max_width = constraint.max_width,
          min_width = 0,
        })
        self.size.height = child_ro.size.height
        self.size.width = constraint.max_width
      end

      function render_object:paint(context, offset)
        local padding_left = math.floor((self.size.width - child_ro.size.width) / 2)
        child_ro:paint(context, {
          x = offset.x + padding_left,
          y = offset.y,
        })
      end

      return render_object
    end,
  }
end

---@param children C.Widget[]
---@return C.Widget
function M.Stack(children)
  return {
    create_render_object = function()
      local children_render_objects = {}
      for _, child in ipairs(children) do
        table.insert(children_render_objects, child:create_render_object())
      end

      local render_object = {
        children = children_render_objects,
        size = { width = 0, height = 0 },
      }

      function render_object:layout(constraint)
        for _, child in ipairs(self.children) do
          child:layout({
            max_width = constraint.max_width,
            min_width = constraint.min_width,
          })
          self.size.height = self.size.height + child.size.height
          self.size.width = math.max(self.size.width, child.size.width)
        end
      end

      function render_object:paint(context, offset)
        local y_offset = offset.y
        for _, child in ipairs(self.children) do
          child:paint(context, {
            x = offset.x,
            y = y_offset,
          })

          y_offset = y_offset + child.size.height
        end
      end

      return render_object
    end,
  }
end

---@generic A
---@param initial_value A
---@return fun(new_value: A), fun(cb: fun(value: A)): fun()
function M.state(initial_value)
  local listeners = {}
  local value = initial_value
  local function set_value(new_value)
    value = new_value
    for _, cb in ipairs(listeners) do
      cb(value)
    end
  end

  local function on_value_change(cb)
    cb(value)
    table.insert(listeners, cb)
    return function()
      for i, listener in ipairs(listeners) do
        if listener == cb then
          table.remove(listeners, i)
          return
        end
      end
    end
  end

  return set_value, on_value_change
end

---@param buffer_id integer
---@param widget C.Widget
---@param constraints C.BoxConstraints
function M.render(buffer_id, widget, constraints)
  local render_object = widget:create_render_object()
  render_object:layout(constraints)

  -- Pre-fill canvas with spaces
  local context = { lines = {}, highlights = {}, actionables = {} }
  for row = 1, render_object.size.height do
    context.lines[row] = string.rep(" ", render_object.size.width)
  end

  render_object:paint(context, { x = 0, y = 0 })

  -- Temporarily enable modifiable if needed
  local was_modifiable = vim.api.nvim_get_option_value("modifiable", { buf = buffer_id })
  if not was_modifiable then
    vim.api.nvim_set_option_value("modifiable", true, { buf = buffer_id })
  end

  vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, context.lines)

  -- Restore modifiable state
  if not was_modifiable then
    vim.api.nvim_set_option_value("modifiable", false, { buf = buffer_id })
  end

  for _, hl in ipairs(context.highlights) do
    vim.api.nvim_buf_set_extmark(buffer_id, ns_id, hl.row, hl.col_start, {
      end_col = hl.col_end,
      hl_group = hl.hl_group,
    })
  end

  -- Clear previous keybinds
  local prev_keybinds = registered_keybinds[buffer_id] or {}
  for _, key in ipairs(prev_keybinds) do
    pcall(vim.keymap.del, "n", key, { buffer = buffer_id })
  end
  registered_keybinds[buffer_id] = {}

  -- Register one keymap per unique keybind
  for keybind, actionables in pairs(context.actionables) do
    vim.keymap.set("n", keybind, function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local row, col = cursor[1] - 1, cursor[2] -- 0-indexed
      for _, act in ipairs(actionables) do
        if row == act.row and col >= act.col_start and col < act.col_end then
          act.on_triggered()
        end
      end
    end, { buffer = buffer_id })
    table.insert(registered_keybinds[buffer_id], keybind)
  end
end

return M
