local StreamBuffer = require('nope.StreamBuffer')

describe('StreamBuffer', function()
  -- Scenario 1: Single complete line
  -- Input: {"hello", ""} means "hello\n"
  -- The empty string after indicates the line is complete
  it('emits single complete line', function()
    local lines = {}
    local stream = StreamBuffer.new(function(line)
      table.insert(lines, line)
    end)

    stream:push({ 'hello', '' })

    assert.same({ 'hello' }, lines)
  end)

  -- Scenario 2: Multiple complete lines in one callback
  -- Input: {"a", "b", "c", ""} means "a\nb\nc\n"
  it('emits multiple complete lines from single callback', function()
    local lines = {}
    local stream = StreamBuffer.new(function(line)
      table.insert(lines, line)
    end)

    stream:push({ 'a', 'b', 'c', '' })

    assert.same({ 'a', 'b', 'c' }, lines)
  end)

  -- Scenario 3: Partial line (no newline yet)
  -- Input: {"partial"} - no trailing empty string means line is incomplete
  -- Should buffer without emitting
  it('buffers partial line without emitting', function()
    local lines = {}
    local stream = StreamBuffer.new(function(line)
      table.insert(lines, line)
    end)

    stream:push({ 'partial' })

    assert.same({}, lines)
  end)

  -- Scenario 4: Partial line completed later
  -- First: {"par"} - incomplete
  -- Then: {"tial", ""} - completes with newline
  it('emits when partial line is completed', function()
    local lines = {}
    local stream = StreamBuffer.new(function(line)
      table.insert(lines, line)
    end)

    stream:push({ 'par' })
    assert.same({}, lines)

    stream:push({ 'tial', '' })
    assert.same({ 'partial' }, lines)
  end)

  -- Scenario 5: Line split across multiple callbacks
  -- {"ab"}, {"cd"}, {"ef", ""} all combine into "abcdef"
  it('assembles line from multiple partial chunks', function()
    local lines = {}
    local stream = StreamBuffer.new(function(line)
      table.insert(lines, line)
    end)

    stream:push({ 'ab' })
    stream:push({ 'cd' })
    stream:push({ 'ef', '' })

    assert.same({ 'abcdef' }, lines)
  end)

  -- Scenario 6: Mixed complete and partial
  -- {"complete", "part"} means "complete\npart" (complete line + partial)
  -- Then {"ial", ""} completes the partial
  it('handles mix of complete and partial lines', function()
    local lines = {}
    local stream = StreamBuffer.new(function(line)
      table.insert(lines, line)
    end)

    stream:push({ 'complete', 'part' })
    assert.same({ 'complete' }, lines)

    stream:push({ 'ial', '' })
    assert.same({ 'complete', 'partial' }, lines)
  end)

  -- Scenario 7: Empty lines are preserved
  -- {"a", "", "b", ""} means "a\n\nb\n" (empty line between a and b)
  it('preserves empty lines', function()
    local lines = {}
    local stream = StreamBuffer.new(function(line)
      table.insert(lines, line)
    end)

    stream:push({ 'a', '', 'b', '' })

    assert.same({ 'a', '', 'b' }, lines)
  end)

  -- Scenario 8: EOF flush emits remaining buffer
  -- If process exits without trailing newline, flush() emits the buffer
  it('flush emits remaining buffered content', function()
    local lines = {}
    local stream = StreamBuffer.new(function(line)
      table.insert(lines, line)
    end)

    stream:push({ 'no_newline' })
    assert.same({}, lines)

    stream:flush()
    assert.same({ 'no_newline' }, lines)
  end)

  -- Scenario 9: EOF with empty buffer
  -- If line was already complete, flush does nothing
  it('flush does nothing when buffer is empty', function()
    local lines = {}
    local stream = StreamBuffer.new(function(line)
      table.insert(lines, line)
    end)

    stream:push({ 'line', '' })
    assert.same({ 'line' }, lines)

    stream:flush()
    assert.same({ 'line' }, lines) -- no duplicate
  end)

  -- Scenario 10: Multiple flushes are safe
  -- Flush clears buffer, so second flush is no-op
  it('multiple flushes only emit once', function()
    local lines = {}
    local stream = StreamBuffer.new(function(line)
      table.insert(lines, line)
    end)

    stream:push({ 'data' })
    stream:flush()
    stream:flush()
    stream:flush()

    assert.same({ 'data' }, lines)
  end)
end)
