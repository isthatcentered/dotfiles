local siblings = require 'isthatcentered.siblings'

describe('isthatcentered.siblings', function()
  local directory
  local original_hidden

  local function create_file(name, lines)
    local path = directory .. '/' .. name
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    vim.fn.writefile(lines or { name }, path)
    return path
  end

  local function open_file(name)
    local buffer = vim.fn.bufadd(directory .. '/' .. name)
    vim.fn.bufload(buffer)
    vim.api.nvim_win_set_buf(0, buffer)
    return buffer
  end

  local function current_name()
    return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')
  end

  before_each(function()
    directory = vim.fn.tempname()
    vim.fn.mkdir(directory, 'p')
    original_hidden = vim.o.hidden
  end)

  after_each(function()
    vim.o.hidden = original_hidden
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(buffer)
      if name:sub(1, #directory + 1) == directory .. '/' then
        vim.api.nvim_buf_delete(buffer, { force = true })
      end
    end
    vim.fn.delete(directory, 'rf')
  end)

  it('cycles through siblings in the same window, wraps, and skips subdirectories', function()
    for _, name in ipairs { 'C', 'A', 'B', 'subfolder/D', 'subfolder/E', 'subfolder/F' } do
      create_file(name)
    end
    open_file 'A'
    local window = vim.api.nvim_get_current_win()

    for _, expected in ipairs { 'B', 'C', 'A' } do
      assert.is_true(siblings.next_file())
      assert.equals(expected, current_name())
      assert.equals(window, vim.api.nvim_get_current_win())
    end
  end)

  it('sorts case-insensitively with a stable order for case-only differences', function()
    for _, name in ipairs { 'apple', 'Banana', 'banana', 'cherry' } do
      create_file(name)
    end
    open_file 'apple'

    for _, expected in ipairs { 'Banana', 'banana', 'cherry', 'apple' } do
      siblings.next_file()
      assert.equals(expected, current_name())
    end
  end)

  it('includes hidden files and files listed in gitignore', function()
    create_file('.gitignore', { 'ignored.log' })
    create_file '.hidden'
    create_file 'A'
    create_file 'ignored.log'
    open_file '.gitignore'

    for _, expected in ipairs { '.hidden', 'A', 'ignored.log', '.gitignore' } do
      siblings.next_file()
      assert.equals(expected, current_name())
    end
  end)

  it('preserves unsaved edits even when hidden is disabled', function()
    create_file 'A'
    create_file 'B'
    local buffer = open_file 'A'
    vim.o.hidden = false
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { 'unsaved edits' })

    siblings.next_file()

    assert.equals('B', current_name())
    assert.is_true(vim.bo[buffer].modified)
    assert.same({ 'unsaved edits' }, vim.api.nvim_buf_get_lines(buffer, 0, -1, false))
    assert.same({ 'A' }, vim.fn.readfile(directory .. '/A'))
    assert.is_false(vim.o.hidden)

    siblings.next_file()
    assert.equals(buffer, vim.api.nvim_get_current_buf())
    assert.same({ 'unsaved edits' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('handles spaces and command metacharacters in filenames', function()
    create_file 'A'
    local name = 'B space % # | [test].txt'
    create_file(name)
    open_file 'A'

    siblings.next_file()
    assert.equals(name, current_name())
  end)

  it('refreshes siblings after files are added or removed', function()
    create_file 'A'
    create_file 'C'
    open_file 'A'
    create_file 'B'

    siblings.next_file()
    assert.equals('B', current_name())

    vim.fn.delete(directory .. '/C')
    siblings.next_file()
    assert.equals('A', current_name())
  end)

  it('does nothing when the current file is the only sibling', function()
    create_file 'A'
    create_file 'subfolder/B'
    local buffer = open_file 'A'

    assert.is_false(siblings.next_file())
    assert.equals(buffer, vim.api.nvim_get_current_buf())
  end)

  it('ignores unnamed and special buffers', function()
    create_file 'A'
    create_file 'B'
    local buffer = open_file 'A'
    vim.bo[buffer].buftype = 'nofile'

    assert.is_false(siblings.next_file())
    assert.equals(buffer, vim.api.nvim_get_current_buf())

    local unnamed = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(0, unnamed)
    assert.is_false(siblings.next_file())
    assert.equals(unnamed, vim.api.nvim_get_current_buf())
    vim.api.nvim_buf_delete(unnamed, { force = true })
  end)

  it('binds Ctrl+j to sibling navigation in normal mode', function()
    create_file 'A'
    create_file 'B'
    open_file 'A'

    local mapping = vim.fn.maparg('<C-j>', 'n', false, true)
    assert.equals('Next sibling file', mapping.desc)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-j>', true, false, true), 'xt', false)
    assert.equals('B', current_name())
  end)
end)
