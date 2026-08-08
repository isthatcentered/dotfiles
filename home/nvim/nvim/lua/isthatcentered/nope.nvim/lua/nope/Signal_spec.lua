local Signal = require('nope.Signal')

describe('Signal', function()
  -- Construction
  describe('new', function()
    it('creates empty signal with no listeners', function()
      local signal = Signal.new()
      assert.same(0, signal:listener_count())
    end)
  end)

  -- listen()
  describe('listen', function()
    it('returns unsubscribe function', function()
      local signal = Signal.new()
      local unsub = signal:listen(function() end)
      assert.same('function', type(unsub))
    end)

    it('listener receives emitted value', function()
      local signal = Signal.new()
      local received
      signal:listen(function(value)
        received = value
      end)
      signal:emit('hello')
      assert.same('hello', received)
    end)

    it('multiple listeners all called', function()
      local signal = Signal.new()
      local call_count = 0
      signal:listen(function()
        call_count = call_count + 1
      end)
      signal:listen(function()
        call_count = call_count + 1
      end)
      signal:emit('test')
      assert.same(2, call_count)
    end)

    it('listeners called in registration order', function()
      local signal = Signal.new()
      local order = {}
      signal:listen(function()
        table.insert(order, 1)
      end)
      signal:listen(function()
        table.insert(order, 2)
      end)
      signal:listen(function()
        table.insert(order, 3)
      end)
      signal:emit('test')
      assert.same({ 1, 2, 3 }, order)
    end)
  end)

  -- emit()
  describe('emit', function()
    it('calls all listeners', function()
      local signal = Signal.new()
      local calls = {}
      signal:listen(function()
        table.insert(calls, 'a')
      end)
      signal:listen(function()
        table.insert(calls, 'b')
      end)
      signal:emit('test')
      assert.same({ 'a', 'b' }, calls)
    end)

    it('passes value to listeners', function()
      local signal = Signal.new()
      local received
      signal:listen(function(value)
        received = value
      end)
      signal:emit(42)
      assert.same(42, received)
    end)

    it('works with no listeners', function()
      local signal = Signal.new()
      -- Should not error
      signal:emit('test')
    end)

    it('works with nil value', function()
      local signal = Signal.new()
      local received = 'not_nil'
      signal:listen(function(value)
        received = value
      end)
      signal:emit(nil)
      assert.same(nil, received)
    end)

    it('works with complex table value', function()
      local signal = Signal.new()
      local received
      signal:listen(function(value)
        received = value
      end)
      local data = { name = 'test', nested = { a = 1, b = 2 } }
      signal:emit(data)
      assert.same(data, received)
    end)
  end)

  -- off()
  describe('off', function()
    it('removes all listeners', function()
      local signal = Signal.new()
      local calls = 0
      signal:listen(function()
        calls = calls + 1
      end)
      signal:listen(function()
        calls = calls + 1
      end)
      signal:off()
      signal:emit('test')
      assert.same(0, calls)
    end)

    it('no error when no listeners exist', function()
      local signal = Signal.new()
      -- Should not error
      signal:off()
    end)
  end)

  -- unsubscribe
  describe('unsubscribe', function()
    it('unsubscribed listener no longer receives events', function()
      local signal = Signal.new()
      local call_count = 0
      local unsub = signal:listen(function()
        call_count = call_count + 1
      end)
      unsub()
      signal:emit('test')
      assert.same(0, call_count)
    end)

    it('other listeners still work after one unsubscribes', function()
      local signal = Signal.new()
      local calls1, calls2 = 0, 0
      local unsub1 = signal:listen(function()
        calls1 = calls1 + 1
      end)
      signal:listen(function()
        calls2 = calls2 + 1
      end)
      unsub1()
      signal:emit('test')
      assert.same(0, calls1)
      assert.same(1, calls2)
    end)

    it('unsubscribe is idempotent', function()
      local signal = Signal.new()
      local unsub = signal:listen(function() end)
      unsub()
      -- Should not error
      unsub()
      unsub()
    end)

    it('unsubscribe during emit does not break iteration', function()
      local signal = Signal.new()
      local calls = {}
      local unsub2
      signal:listen(function()
        table.insert(calls, 1)
        if unsub2 then
          unsub2()
        end
      end)
      unsub2 = signal:listen(function()
        table.insert(calls, 2)
      end)
      signal:listen(function()
        table.insert(calls, 3)
      end)
      signal:emit('test')
      -- All listeners should still be called for this emit
      assert.same({ 1, 2, 3 }, calls)
    end)
  end)

  -- edge cases
  describe('edge cases', function()
    it('listener throws error - propagates and stops further listeners', function()
      local signal = Signal.new()
      local calls = {}
      signal:listen(function()
        table.insert(calls, 1)
      end)
      signal:listen(function()
        error('listener error')
      end)
      signal:listen(function()
        table.insert(calls, 3)
      end)
      assert.has_error(function()
        signal:emit('test')
      end)
      -- First listener called, error thrown, third not called
      assert.same({ 1 }, calls)
    end)

    it('listener subscribes new listener during emit', function()
      local signal = Signal.new()
      local calls = {}
      signal:listen(function()
        table.insert(calls, 'first')
        signal:listen(function()
          table.insert(calls, 'new')
        end)
      end)
      signal:emit('test')
      -- New listener should NOT be called during same emit (due to copy)
      assert.same({ 'first' }, calls)
      -- But should be called on next emit
      calls = {}
      signal:emit('test')
      assert.same({ 'first', 'new' }, calls)
    end)

    it('listener emits during emit (re-entrant)', function()
      local signal = Signal.new()
      local calls = {}
      local count = 0
      signal:listen(function()
        count = count + 1
        table.insert(calls, count)
        if count < 3 then
          signal:emit('test')
        end
      end)
      signal:emit('test')
      assert.same({ 1, 2, 3 }, calls)
    end)
  end)

  -- listener_count()
  describe('listener_count', function()
    it('returns 0 for empty signal', function()
      local signal = Signal.new()
      assert.same(0, signal:listener_count())
    end)

    it('counts all listeners', function()
      local signal = Signal.new()
      signal:listen(function() end)
      signal:listen(function() end)
      signal:listen(function() end)
      assert.same(3, signal:listener_count())
    end)

    it('decrements after unsubscribe', function()
      local signal = Signal.new()
      local unsub = signal:listen(function() end)
      signal:listen(function() end)
      assert.same(2, signal:listener_count())
      unsub()
      assert.same(1, signal:listener_count())
    end)

    it('returns 0 after off()', function()
      local signal = Signal.new()
      signal:listen(function() end)
      signal:listen(function() end)
      signal:off()
      assert.same(0, signal:listener_count())
    end)
  end)
end)
