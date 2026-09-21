local views = require 'todo_prototype.views'

describe('board presentation', function()
  for _, size in ipairs { { 60, 19 }, { 110, 30 }, { 120, 36 }, { 121, 36 }, { 305, 74 } } do
    for _, preview in ipairs { false, true } do
      it(('keeps equal columns and all floats within %dx%d, preview %s'):format(size[1], size[2], tostring(preview)), function()
        local state = { backlog = { task() }, active = {}, done = {}, lane = 1, selected = 1, preview_visible = preview }
        local widths, previews, dividers = {}, 0, 0
        for _, p in ipairs(views.build(state, size[1], size[2])) do
          local border = p.border == 'rounded' and 2 or 0
          assert(p.x >= 0 and p.y >= 0)
          assert(p.x + p.width + border <= size[1])
          assert(p.y + p.height + border < size[2])
          if p.lane then
            widths[#widths + 1] = p.width
            eq(p.focused, p.lane == 1)
          end
          if p.preview then previews = previews + 1 end
          if p.lines[1] == '┬' then
            dividers = dividers + 1
            eq(p.lines[#p.lines], '┴')
            eq(#p.lines, p.height)
          end
        end
        eq(#widths, 3)
        eq(widths[1], widths[2])
        eq(widths[2], widths[3])
        eq(previews, preview and 1 or 0)
        eq(dividers, 2)
      end)
    end
  end
  it('wraps long Unicode text completely and preserves paragraphs in the sidebar', function()
    local t = task()
    t.title = string.rep('日', 100)
    t.description = string.rep('界', 300) .. '\n\nlast paragraph'
    local state = { backlog = { t }, active = {}, done = {}, lane = 1, selected = 1, preview_visible = true }
    for _, p in ipairs(views.build(state, 110, 30)) do
      if p.preview then
        local content = table.concat(p.lines, '\n')
        local _, title_count = content:gsub('日', '')
        local _, description_count = content:gsub('界', '')
        eq(title_count, 100)
        eq(description_count, 300)
        assert(content:find('last paragraph', 1, true))
        for _, line in ipairs(p.lines) do assert(vim.fn.strdisplaywidth(line) < p.width) end
        return
      end
    end
    error('missing preview')
  end)
end)
