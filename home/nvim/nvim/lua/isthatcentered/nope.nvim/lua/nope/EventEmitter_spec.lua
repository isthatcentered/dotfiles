local EventEmitter = require('nope.EventEmitter')

describe('EventEmitter', function()
  -- Construction
  describe('new', function()
    it('creates empty emitter with no listeners', function()
      local emitter = EventEmitter.new()
      assert.same({}, emitter._listeners)
    end)
  end)

  -- on()
  describe('on', function()
    it('returns unsubscribe function', function()
      local emitter = EventEmitter.new()
      local unsub = emitter:on('test', function() end)
      assert.same('function', type(unsub))
    end)

    it('listener receives emitted event args', function()
      local emitter = EventEmitter.new()
      local received
      emitter:on('test', function(arg)
        received = arg
      end)
      emitter:emit('test', 'hello')
      assert.same('hello', received)
    end)

    it('multiple listeners for same event all called', function()
      local emitter = EventEmitter.new()
      local call_count = 0
      emitter:on('test', function()
        call_count = call_count + 1
      end)
      emitter:on('test', function()
        call_count = call_count + 1
      end)
      emitter:emit('test')
      assert.same(2, call_count)
    end)

    it('listeners called in registration order', function()
      local emitter = EventEmitter.new()
      local order = {}
      emitter:on('test', function()
        table.insert(order, 1)
      end)
      emitter:on('test', function()
        table.insert(order, 2)
      end)
      emitter:on('test', function()
        table.insert(order, 3)
      end)
      emitter:emit('test')
      assert.same({ 1, 2, 3 }, order)
    end)

    it('different events are independent', function()
      local emitter = EventEmitter.new()
      local a_calls, b_calls = 0, 0
      emitter:on('a', function()
        a_calls = a_calls + 1
      end)
      emitter:on('b', function()
        b_calls = b_calls + 1
      end)
      emitter:emit('a')
      assert.same(1, a_calls)
      assert.same(0, b_calls)
    end)

    it('listener not called for other events', function()
      local emitter = EventEmitter.new()
      local called = false
      emitter:on('test', function()
        called = true
      end)
      emitter:emit('other')
      assert.same(false, called)
    end)
  end)

  -- emit()
  describe('emit', function()
    it('calls all listeners for event', function()
      local emitter = EventEmitter.new()
      local calls = {}
      emitter:on('test', function()
        table.insert(calls, 'a')
      end)
      emitter:on('test', function()
        table.insert(calls, 'b')
      end)
      emitter:emit('test')
      assert.same({ 'a', 'b' }, calls)
    end)

    it('passes all arguments to listeners', function()
      local emitter = EventEmitter.new()
      local received = {}
      emitter:on('test', function(a, b, c)
        received = { a, b, c }
      end)
      emitter:emit('test', 1, 2, 3)
      assert.same({ 1, 2, 3 }, received)
    end)

    it('works with no listeners', function()
      local emitter = EventEmitter.new()
      -- Should not error
      emitter:emit('test', 'arg')
    end)

    it('works with multiple args', function()
      local emitter = EventEmitter.new()
      local sum = 0
      emitter:on('add', function(a, b, c, d)
        sum = a + b + c + d
      end)
      emitter:emit('add', 1, 2, 3, 4)
      assert.same(10, sum)
    end)

    it('works with zero args', function()
      local emitter = EventEmitter.new()
      local called = false
      emitter:on('test', function()
        called = true
      end)
      emitter:emit('test')
      assert.same(true, called)
    end)
  end)

  -- once()
  describe('once', function()
    it('listener called only once then removed', function()
      local emitter = EventEmitter.new()
      local call_count = 0
      emitter:once('test', function()
        call_count = call_count + 1
      end)
      emitter:emit('test')
      emitter:emit('test')
      emitter:emit('test')
      assert.same(1, call_count)
    end)

    it('returns unsubscribe function', function()
      local emitter = EventEmitter.new()
      local unsub = emitter:once('test', function() end)
      assert.same('function', type(unsub))
    end)

    it('unsubscribe before emit prevents call', function()
      local emitter = EventEmitter.new()
      local called = false
      local unsub = emitter:once('test', function()
        called = true
      end)
      unsub()
      emitter:emit('test')
      assert.same(false, called)
    end)

    it('receives arguments', function()
      local emitter = EventEmitter.new()
      local received
      emitter:once('test', function(arg)
        received = arg
      end)
      emitter:emit('test', 'value')
      assert.same('value', received)
    end)
  end)

  -- off()
  describe('off', function()
    it('removes all listeners for specific event', function()
      local emitter = EventEmitter.new()
      local a_calls, b_calls = 0, 0
      emitter:on('a', function()
        a_calls = a_calls + 1
      end)
      emitter:on('a', function()
        a_calls = a_calls + 1
      end)
      emitter:on('b', function()
        b_calls = b_calls + 1
      end)
      emitter:off('a')
      emitter:emit('a')
      emitter:emit('b')
      assert.same(0, a_calls)
      assert.same(1, b_calls)
    end)

    it('removes all listeners when no event specified', function()
      local emitter = EventEmitter.new()
      local calls = 0
      emitter:on('a', function()
        calls = calls + 1
      end)
      emitter:on('b', function()
        calls = calls + 1
      end)
      emitter:off()
      emitter:emit('a')
      emitter:emit('b')
      assert.same(0, calls)
    end)

    it('no error when removing from event with no listeners', function()
      local emitter = EventEmitter.new()
      -- Should not error
      emitter:off('nonexistent')
    end)
  end)

  -- Unsubscribe
  describe('unsubscribe', function()
    it('unsubscribed listener no longer receives events', function()
      local emitter = EventEmitter.new()
      local call_count = 0
      local unsub = emitter:on('test', function()
        call_count = call_count + 1
      end)
      unsub()
      emitter:emit('test')
      assert.same(0, call_count)
    end)

    it('other listeners still work after one unsubscribes', function()
      local emitter = EventEmitter.new()
      local calls1, calls2 = 0, 0
      local unsub1 = emitter:on('test', function()
        calls1 = calls1 + 1
      end)
      emitter:on('test', function()
        calls2 = calls2 + 1
      end)
      unsub1()
      emitter:emit('test')
      assert.same(0, calls1)
      assert.same(1, calls2)
    end)

    it('unsubscribe is idempotent', function()
      local emitter = EventEmitter.new()
      local unsub = emitter:on('test', function() end)
      unsub()
      -- Should not error
      unsub()
      unsub()
    end)

    it('unsubscribe during emit does not break iteration', function()
      local emitter = EventEmitter.new()
      local calls = {}
      local unsub2
      emitter:on('test', function()
        table.insert(calls, 1)
        if unsub2 then
          unsub2()
        end
      end)
      unsub2 = emitter:on('test', function()
        table.insert(calls, 2)
      end)
      emitter:on('test', function()
        table.insert(calls, 3)
      end)
      emitter:emit('test')
      -- All listeners should still be called for this notification
      assert.same({ 1, 2, 3 }, calls)
    end)
  end)

  -- Edge cases
  describe('edge cases', function()
    it('listener throws error - propagates and stops further listeners', function()
      local emitter = EventEmitter.new()
      local calls = {}
      emitter:on('test', function()
        table.insert(calls, 1)
      end)
      emitter:on('test', function()
        error('listener error')
      end)
      emitter:on('test', function()
        table.insert(calls, 3)
      end)
      assert.has_error(function()
        emitter:emit('test')
      end)
      -- First listener called, error thrown, third not called
      assert.same({ 1 }, calls)
    end)

    it('listener subscribes new listener during emit', function()
      local emitter = EventEmitter.new()
      local calls = {}
      emitter:on('test', function()
        table.insert(calls, 'first')
        emitter:on('test', function()
          table.insert(calls, 'new')
        end)
      end)
      emitter:emit('test')
      -- New listener should NOT be called during same emit (due to copy)
      assert.same({ 'first' }, calls)
      -- But should be called on next emit
      calls = {}
      emitter:emit('test')
      assert.same({ 'first', 'new' }, calls)
    end)

    it('listener emits same event during emit (re-entrant)', function()
      local emitter = EventEmitter.new()
      local calls = {}
      local count = 0
      emitter:on('test', function()
        count = count + 1
        table.insert(calls, count)
        if count < 3 then
          emitter:emit('test')
        end
      end)
      emitter:emit('test')
      assert.same({ 1, 2, 3 }, calls)
    end)

    it('event names can be any string including empty', function()
      local emitter = EventEmitter.new()
      local called = false
      emitter:on('', function()
        called = true
      end)
      emitter:emit('')
      assert.same(true, called)
    end)
  end)

  -- Memory
  describe('memory', function()
    it('unsubscribed listeners removed from internal list', function()
      local emitter = EventEmitter.new()
      local unsub1 = emitter:on('test', function() end)
      local unsub2 = emitter:on('test', function() end)
      assert.same(2, #emitter._listeners['test'])
      unsub1()
      assert.same(1, #emitter._listeners['test'])
      unsub2()
      assert.same(0, #emitter._listeners['test'])
    end)
  end)

  -- listener_count()
  describe('listener_count', function()
    it('returns 0 for empty emitter', function()
      local emitter = EventEmitter.new()
      assert.same(0, emitter:listener_count())
    end)

    it('counts listeners across multiple events', function()
      local emitter = EventEmitter.new()
      emitter:on('a', function() end)
      emitter:on('a', function() end)
      emitter:on('b', function() end)
      assert.same(3, emitter:listener_count())
    end)

    it('decrements after unsubscribe', function()
      local emitter = EventEmitter.new()
      local unsub = emitter:on('test', function() end)
      emitter:on('test', function() end)
      assert.same(2, emitter:listener_count())
      unsub()
      assert.same(1, emitter:listener_count())
    end)

    it('decrements after off(event)', function()
      local emitter = EventEmitter.new()
      emitter:on('a', function() end)
      emitter:on('a', function() end)
      emitter:on('b', function() end)
      assert.same(3, emitter:listener_count())
      emitter:off('a')
      assert.same(1, emitter:listener_count())
    end)

    it('returns 0 after off()', function()
      local emitter = EventEmitter.new()
      emitter:on('a', function() end)
      emitter:on('b', function() end)
      emitter:off()
      assert.same(0, emitter:listener_count())
    end)
  end)
end)
