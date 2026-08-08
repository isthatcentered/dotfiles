local renderer = require('nope.ui.renderer')
local Text = require('nope.ui.nodes.Text')
local Stack = require('nope.ui.nodes.Stack')
local Array = require('nope.ui.nodes.Array')
local Padding = require('nope.ui.nodes.Padding')
local Extmark = require('nope.ui.nodes.Extmark')
local Keybind = require('nope.ui.nodes.Keybind')

describe('renderer', function()
  describe('render', function()
    describe('Text', function()
      it('renders single line', function()
        local node = Text({ text = 'hello' })
        local output = renderer.render(node)
        assert.same({ 'hello' }, output.lines)
      end)

      it('renders empty text', function()
        local node = Text({ text = '' })
        local output = renderer.render(node)
        assert.same({ '' }, output.lines)
      end)

      it('adds highlight extmark when hl specified', function()
        local node = Text({ text = 'hello', hl = 'Comment' })
        local output = renderer.render(node)
        assert.same(1, #output.extmarks)
        assert.same(0, output.extmarks[1].line)
        assert.same('Comment', output.extmarks[1].opts.hl_group)
      end)
    end)

    describe('Stack', function()
      it('renders children vertically', function()
        local node = Stack({}, {
          Text({ text = 'line1' }),
          Text({ text = 'line2' }),
          Text({ text = 'line3' }),
        })
        local output = renderer.render(node)
        assert.same({ 'line1', 'line2', 'line3' }, output.lines)
      end)

      it('handles empty stack', function()
        local node = Stack({}, {})
        local output = renderer.render(node)
        assert.same({}, output.lines)
      end)

      it('skips false children (conditional rendering)', function()
        local show_middle = false
        -- Use vim.tbl_filter pattern for conditional children
        local children = vim.tbl_filter(function(c)
          return c
        end, {
          Text({ text = 'a' }),
          show_middle and Text({ text = 'middle' }),
          Text({ text = 'b' }),
        })
        local node = Stack({}, children)
        local output = renderer.render(node)
        assert.same({ 'a', 'b' }, output.lines)
      end)

      it('nests stacks', function()
        local node = Stack({}, {
          Text({ text = 'outer1' }),
          Stack({}, {
            Text({ text = 'inner1' }),
            Text({ text = 'inner2' }),
          }),
          Text({ text = 'outer2' }),
        })
        local output = renderer.render(node)
        assert.same({ 'outer1', 'inner1', 'inner2', 'outer2' }, output.lines)
      end)
    end)

    describe('Array', function()
      it('renders items with render function', function()
        local node = Array({
          items = { 'a', 'b', 'c' },
          key = function(item)
            return item
          end,
          render = function(item)
            return Text({ text = item })
          end,
        })
        local output = renderer.render(node)
        assert.same({ 'a', 'b', 'c' }, output.lines)
      end)

      it('passes index to render function', function()
        local node = Array({
          items = { 'x', 'y' },
          key = function(_, i)
            return tostring(i)
          end,
          render = function(item, index)
            return Text({ text = item .. tostring(index) })
          end,
        })
        local output = renderer.render(node)
        assert.same({ 'x1', 'y2' }, output.lines)
      end)

      it('handles empty items', function()
        local node = Array({
          items = {},
          key = function(item)
            return item
          end,
          render = function(item)
            return Text({ text = item })
          end,
        })
        local output = renderer.render(node)
        assert.same({}, output.lines)
      end)
    end)

    describe('Padding', function()
      it('adds top padding', function()
        local node = Padding({ top = 2 }, {
          Text({ text = 'content' }),
        })
        local output = renderer.render(node)
        assert.same({ '', '', 'content' }, output.lines)
      end)

      it('adds bottom padding', function()
        local node = Padding({ bottom = 2 }, {
          Text({ text = 'content' }),
        })
        local output = renderer.render(node)
        assert.same({ 'content', '', '' }, output.lines)
      end)

      it('adds left padding', function()
        local node = Padding({ left = 4 }, {
          Text({ text = 'content' }),
        })
        local output = renderer.render(node)
        assert.same({ '    content' }, output.lines)
      end)

      it('combines all padding', function()
        local node = Padding({ top = 1, bottom = 1, left = 2 }, {
          Text({ text = 'content' }),
        })
        local output = renderer.render(node)
        assert.same({ '', '  content', '' }, output.lines)
      end)

      it('nests padding accumulates left', function()
        local node = Padding({ left = 2 }, {
          Padding({ left = 2 }, {
            Text({ text = 'nested' }),
          }),
        })
        local output = renderer.render(node)
        assert.same({ '    nested' }, output.lines)
      end)
    end)

    describe('Extmark', function()
      it('adds extmark to child lines', function()
        local node = Extmark({ sign_text = '>' }, {
          Text({ text = 'content' }),
        })
        local output = renderer.render(node)
        assert.same({ 'content' }, output.lines)
        -- Should have extmark for sign
        local found = false
        for _, em in ipairs(output.extmarks) do
          if em.opts.sign_text == '>' then
            found = true
          end
        end
        assert.is_true(found)
      end)

      it('sets sign_hl_group', function()
        local node = Extmark({ sign_text = 'X', sign_hl = 'Error' }, {
          Text({ text = 'test' }),
        })
        local output = renderer.render(node)
        local em = output.extmarks[#output.extmarks]
        assert.same('Error', em.opts.sign_hl_group)
      end)

      it('sets virt_text', function()
        local node = Extmark({
          virt_text = { { ' suffix', 'Comment' } },
          virt_text_pos = 'eol',
        }, {
          Text({ text = 'line' }),
        })
        local output = renderer.render(node)
        local em = output.extmarks[#output.extmarks]
        assert.same({ { ' suffix', 'Comment' } }, em.opts.virt_text)
        assert.same('eol', em.opts.virt_text_pos)
      end)
    end)

    describe('Keybind', function()
      it('registers keybind for line range', function()
        local callback = function() end
        local node = Keybind({ key = '<CR>', on_press = callback }, {
          Text({ text = 'line1' }),
          Text({ text = 'line2' }),
        })
        local output = renderer.render(node)
        assert.same(1, #output.keybinds)
        assert.same('<CR>', output.keybinds[1].key)
        assert.same(1, output.keybinds[1].start_line)
        assert.same(2, output.keybinds[1].end_line)
        assert.same(callback, output.keybinds[1].callback)
      end)

      it('nested keybinds have correct ranges', function()
        local node = Stack({}, {
          Text({ text = 'before' }),
          Keybind({ key = 'a', on_press = function() end }, {
            Text({ text = 'keybind-line' }),
          }),
          Text({ text = 'after' }),
        })
        local output = renderer.render(node)
        assert.same(1, #output.keybinds)
        assert.same(2, output.keybinds[1].start_line)
        assert.same(2, output.keybinds[1].end_line)
      end)
    end)
  end)
end)
