local module_name = 'isthatcentered.review'
local namespace = vim.api.nvim_create_namespace(module_name)
local review, directory, clipboard, messages, response, original

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'xt', false)
end

local function open_file(name, lines)
  local path = directory .. '/' .. name
  vim.fn.writefile(lines or { 'alpha', 'beta', 'gamma', 'delta' }, path)
  local buffer = vim.fn.bufadd(path)
  vim.fn.bufload(buffer)
  vim.api.nvim_win_set_buf(0, buffer)
  return buffer
end

local function marks(buffer)
  return vim.api.nvim_buf_get_extmarks(buffer or 0, namespace, 0, -1, { details = true })
end

local function collected()
  assert.is_true(review.collect())
  return vim.json.decode(clipboard).comments
end

describe('isthatcentered.review', function()
  before_each(function()
    original = {
      input = vim.ui.input,
      notify = vim.notify,
      system = vim.system,
      has = vim.fn.has,
      cwd = vim.fn.getcwd(),
      clipboard = vim.g.clipboard,
      clipboard_option = vim.o.clipboard,
      leader = vim.g.mapleader,
      hidden = vim.o.hidden,
      selection = vim.o.selection,
    }
    directory = vim.fn.tempname()
    vim.fn.mkdir(directory .. '/.git', 'p')
    vim.cmd.cd(vim.fn.fnameescape(directory))
    vim.g.mapleader = ' '
    vim.o.hidden = true
    vim.o.clipboard = ''
    vim.o.selection = 'inclusive'
    clipboard, messages, response = 'previous clipboard', {}, 'Please simplify this.'
    vim.g.clipboard = {
      name = 'feedback-test',
      copy = {
        ['+'] = function(lines)
          clipboard = table.concat(lines, '\n')
        end,
        ['*'] = function() end,
      },
      paste = {
        ['+'] = function()
          return { vim.split(clipboard, '\n', { plain = true }), 'v' }
        end,
        ['*'] = function()
          return { {}, 'v' }
        end,
      },
      cache_enabled = 0,
    }
    vim.cmd 'unlet! g:loaded_clipboard_provider'
    vim.cmd 'runtime autoload/provider/clipboard.vim'
    vim.ui.input = function(_, callback)
      callback(response)
    end
    vim.notify = function(message)
      table.insert(messages, message)
    end
    package.loaded[module_name] = nil
    review = require(module_name)
    open_file 'sample.txt'
  end)

  after_each(function()
    feed '<Esc>'
    vim.cmd 'cclose'
    vim.cmd.cd(vim.fn.fnameescape(original.cwd))
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(buffer):sub(1, #directory + 1) == directory .. '/' then
        vim.api.nvim_buf_delete(buffer, { force = true })
      end
    end
    vim.wait(10)
    vim.ui.input, vim.notify, vim.system, vim.fn.has = original.input, original.notify, original.system, original.has
    vim.g.clipboard, vim.g.mapleader = original.clipboard, original.leader
    vim.o.clipboard, vim.o.hidden, vim.o.selection = original.clipboard_option, original.hidden, original.selection
    vim.fn.delete(directory, 'rf')
  end)

  it('adds feedback through the Normal mapping without touching source, disk or undo history', function()
    local buffer = vim.api.nvim_get_current_buf()
    local undo = vim.fn.undotree().seq_last
    feed 'j R'
    assert.is_false(vim.bo.modified)
    assert.equals(undo, vim.fn.undotree().seq_last)
    assert.same({ 'alpha', 'beta', 'gamma', 'delta' }, vim.fn.readfile(directory .. '/sample.txt'))
    assert.equals('AgentFeedback', marks()[1][4].hl_group)
    assert.equals('!', vim.trim(marks()[1][4].sign_text))
    local entry = collected()[1]
    assert.same({ line = 2, column = 1 }, entry.start)
    assert.same({ line = 3, column = 1 }, entry['end'])
    assert.equals('line', entry.selection)
    assert.equals(response, entry.comment)
    assert.equals('sample.txt', entry.file)
    assert.equals(directory, entry.project_root)
    assert.same({}, marks(buffer))
  end)

  it('uses the current linewise selection, not stale Visual marks', function()
    feed 'Vj<Esc>G Vk R'
    local entry = collected()[1]
    assert.same({ line = 3, column = 1 }, entry.start)
    assert.same({ line = 5, column = 1 }, entry['end'])
  end)

  it('captures a multibyte character with byte-accurate exclusive endpoints', function()
    open_file('unicode.txt', { 'a€z' })
    feed '0lv R'
    local entry = collected()[1]
    assert.equals('character', entry.selection)
    assert.same({ line = 1, column = 2 }, entry.start)
    assert.same({ line = 1, column = 5 }, entry['end'])
  end)

  it('normalizes reversed characterwise selections', function()
    feed '0llvhh R'
    local entry = collected()[1]
    assert.same({ line = 1, column = 1 }, entry.start)
    assert.same({ line = 1, column = 4 }, entry['end'])
  end)

  it('honors exclusive Visual selections', function()
    vim.o.selection = 'exclusive'
    feed '0vll R'
    local entry = collected()[1]
    assert.same({ line = 1, column = 1 }, entry.start)
    assert.same({ line = 1, column = 3 }, entry['end'])
  end)

  it('handles multiline character selections', function()
    feed '0lvjl R'
    local entry = collected()[1]
    assert.same({ line = 1, column = 2 }, entry.start)
    assert.same({ line = 2, column = 4 }, entry['end'])
  end)

  it('can annotate an empty line without creating an empty range', function()
    open_file('empty.txt', { '' })
    feed 'v R'
    local entry = collected()[1]
    assert.same({ line = 1, column = 1 }, entry.start)
    assert.same({ line = 2, column = 1 }, entry['end'])
  end)

  for _, cancel in ipairs { false, '   ' } do
    it('cancels ' .. (cancel == false and 'nil input' or 'blank input') .. ' without leaving a mark', function()
      if cancel == false then
        response = nil
      else
        response = cancel
      end
      review.add()
      assert.same({}, marks())
      assert.is_false(review.collect())
      assert.equals('previous clipboard', clipboard)
    end)
  end

  it('tracks inserted lines and reads current positions when collecting', function()
    feed 'jVj R'
    vim.api.nvim_buf_set_lines(0, 1, 1, false, { 'inserted above start' })
    vim.api.nvim_buf_set_lines(0, 4, 4, false, { 'outside exclusive end' })
    local entry = collected()[1]
    assert.same({ line = 3, column = 1 }, entry.start)
    assert.same({ line = 5, column = 1 }, entry['end'])
  end)

  it('keeps deleted-range feedback until undo restores its location', function()
    feed 'j Rdd'
    assert.is_false(review.collect())
    assert.equals('previous clipboard', clipboard)
    assert.is_true(marks()[1][4].invalid)
    feed 'u'
    local entry = collected()[1]
    assert.same({ line = 2, column = 1 }, entry.start)
    assert.same({ line = 3, column = 1 }, entry['end'])
  end)

  it('can discard feedback whose range was deleted', function()
    feed 'j Rdd'
    assert.equals(1, review.remove())
    assert.same({}, marks())
    assert.is_false(review.collect())
  end)

  it('can navigate to and discard a deleted range at the EOF boundary', function()
    feed 'G Rdd'
    assert.is_false(review.collect())
    review.list()
    feed '<CR>'
    assert.equals(1, review.remove())
    assert.is_false(review.collect())
  end)

  it('collects overlapping feedback independently and gathers all buffers', function()
    review.add()
    review.add()
    local first = vim.api.nvim_get_current_buf()
    open_file 'second.txt'
    response = 'Second file'
    review.add()
    local entries = collected()
    assert.equals(3, #entries)
    assert.equals('sample.txt', entries[1].file)
    assert.equals('sample.txt', entries[2].file)
    assert.equals('second.txt', entries[3].file)
    assert.same({}, marks(first))
    assert.same({}, marks())
    local output = clipboard
    assert.is_false(review.collect())
    assert.equals(output, clipboard)
  end)

  it('discards only feedback under the current cursor', function()
    review.add()
    review.add()
    feed 'j R'
    assert.equals(1, review.remove())
    assert.equals(2, #collected())
  end)

  it('keeps a pending prompt attached to its original buffer while edits happen', function()
    local confirm
    vim.ui.input = function(_, callback)
      confirm = callback
    end
    local buffer = vim.api.nvim_get_current_buf()
    review.add()
    vim.api.nvim_buf_set_lines(buffer, 0, 0, false, { 'new first line' })
    open_file 'second.txt'
    confirm 'Original buffer'
    local entry = collected()[1]
    assert.equals('sample.txt', entry.file)
    assert.same({ line = 2, column = 1 }, entry.start)
  end)

  it('cancels a pending prompt if its buffer was wiped', function()
    local confirm
    vim.ui.input = function(_, callback)
      confirm = callback
    end
    local buffer = vim.api.nvim_get_current_buf()
    review.add()
    vim.api.nvim_buf_delete(buffer, { force = true })
    confirm 'Too late'
    assert.is_false(review.collect())
  end)

  it('removes unloaded-buffer feedback with a notice, preserving other buffers', function()
    local buffer = vim.api.nvim_get_current_buf()
    review.add()
    open_file 'second.txt'
    review.add()
    vim.api.nvim_buf_delete(buffer, { force = true })
    vim.wait(10)
    assert.matches('Buffer unloaded', messages[#messages])
    local entries = collected()
    assert.equals(1, #entries)
    assert.equals('second.txt', entries[1].file)
  end)

  it('keeps feedback when clipboard readback differs', function()
    review.add()
    local getreg = vim.fn.getreg
    vim.fn.getreg = function()
      return 'different contents'
    end
    local ok = review.collect()
    vim.fn.getreg = getreg
    assert.is_false(ok)
    assert.equals(1, #marks())
    assert.equals(1, #collected())
  end)

  it('keeps feedback when the provider raises or is unavailable', function()
    review.add()
    local setreg = vim.fn.setreg
    vim.fn.setreg = function()
      error 'Clipboard failure'
    end
    local ok = review.collect()
    vim.fn.setreg = setreg
    assert.is_false(ok)
    assert.equals(1, #marks())
    vim.fn.has = function(feature)
      return feature == 'clipboard' and 0 or original.has(feature)
    end
    assert.is_false(review.collect())
    vim.fn.has = original.has
    assert.equals(1, #collected())
  end)

  it('waits for tmux copy success before removing feedback', function()
    review.add()
    vim.g.clipboard = 'tmux'
    local code, copied = 1, nil
    vim.system = function(command, options)
      assert.same({ 'tmux', 'load-buffer', '-w', '-' }, command)
      copied = options.stdin
      return {
        wait = function()
          return { code = code, stderr = code == 1 and 'tmux failed' or '' }
        end,
      }
    end
    assert.is_false(review.collect())
    assert.equals(1, #marks())
    code = 0
    assert.is_true(review.collect())
    assert.equals(1, #vim.json.decode(copied).comments)
    assert.same({}, marks())
  end)

  it('copies through a real isolated tmux server without touching the user clipboard', function()
    if vim.fn.executable 'tmux' == 0 then
      pending 'tmux is not installed'
      return
    end
    local socket = directory .. '/tmux.sock'
    local start = vim.system({ 'tmux', '-S', socket, '-f', '/dev/null', 'new-session', '-d', '-s', 'feedback', 'cat' }):wait(5000)
    assert.equals(0, start.code, start.stderr)
    local tmux_env = vim.env.TMUX
    local ok, err = pcall(function()
      vim.env.TMUX = socket .. ',0,0'
      vim.g.clipboard = 'tmux'
      review.add()
      assert.is_true(review.collect())
      local result = vim.system({ 'tmux', '-S', socket, 'save-buffer', '-' }, { text = true }):wait(5000)
      assert.equals(0, result.code, result.stderr)
      local output = vim.json.decode(result.stdout)
      assert.equals(response, output.comments[1].comment)
      assert.same({}, marks())
    end)
    vim.env.TMUX = tmux_env
    vim.system({ 'tmux', '-S', socket, 'kill-server' }):wait(5000)
    assert.is_true(ok, tostring(err))
  end)

  it('lists current locations and leaves unrelated quickfix lists intact on collection', function()
    review.add()
    feed 'j R'
    assert.is_true(review.list())
    local ours = vim.fn.getqflist({ id = 0 }).id
    assert.equals(2, #vim.fn.getqflist())
    vim.cmd 'cclose'
    vim.fn.setqflist({}, ' ', { title = 'Unrelated', items = { { text = 'Keep this' } } })
    assert.equals(2, #collected())
    assert.equals('Keep this', vim.fn.getqflist()[1].text)
    assert.same({}, vim.fn.getqflist({ id = ours, items = 0 }).items)
  end)

  it('uses stable project-relative paths even if cwd changes after annotation', function()
    review.add()
    vim.cmd.cd(vim.fn.fnameescape(original.cwd))
    local entry = collected()[1]
    assert.equals(directory, entry.project_root)
    assert.equals('sample.txt', entry.file)
  end)

  it('rejects block selections and unnamed buffers without leaking marks', function()
    feed '<C-v> R<Esc>'
    assert.same({}, marks())
    vim.cmd 'enew'
    assert.is_false(review.add())
    assert.same({}, marks())
  end)
end)
