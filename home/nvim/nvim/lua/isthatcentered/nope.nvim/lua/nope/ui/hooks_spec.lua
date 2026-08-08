local hooks = require('nope.ui.hooks')
local VNode = require('nope.ui.VNode')

describe('hooks', function()
  local instance
  local rerender_count

  before_each(function()
    instance = VNode.create_instance(function() end, {})
    rerender_count = 0
    hooks._set_context(instance, function()
      rerender_count = rerender_count + 1
    end)
  end)

  after_each(function()
    hooks._clear_context()
  end)

  describe('use_state', function()
    it('returns initial value on first call', function()
      local value, _ = hooks.use_state(42)
      assert.same(42, value)
    end)

    it('returns same value on subsequent calls (same render)', function()
      local value1, set1 = hooks.use_state(42)
      instance._hook_index = 1 -- simulate same hook position
      local value2, _ = hooks.use_state(42)
      assert.same(42, value1)
      assert.same(42, value2)
    end)

    it('setter updates value', function()
      local _, setter = hooks.use_state(1)
      setter(2)
      instance._hook_index = 1
      local value, _ = hooks.use_state(1)
      assert.same(2, value)
    end)

    it('setter triggers rerender', function()
      local _, setter = hooks.use_state(1)
      assert.same(0, rerender_count)
      setter(2)
      assert.same(1, rerender_count)
    end)

    it('setter does not trigger rerender if value unchanged', function()
      local _, setter = hooks.use_state(1)
      setter(1)
      assert.same(0, rerender_count)
    end)

    it('multiple states are independent', function()
      local a, set_a = hooks.use_state('a')
      local b, set_b = hooks.use_state('b')

      assert.same('a', a)
      assert.same('b', b)

      set_a('A')
      set_b('B')

      instance._hook_index = 1
      local a2, _ = hooks.use_state('a')
      local b2, _ = hooks.use_state('b')

      assert.same('A', a2)
      assert.same('B', b2)
    end)
  end)

  describe('use_mount', function()
    it('calls callback on first render', function()
      local called = false
      hooks.use_mount(function()
        called = true
      end)
      assert.is_true(called)
    end)

    it('does not call callback on subsequent renders', function()
      local call_count = 0
      hooks.use_mount(function()
        call_count = call_count + 1
      end)
      assert.same(1, call_count)

      -- Simulate re-render
      instance._hook_index = 1
      hooks.use_mount(function()
        call_count = call_count + 1
      end)
      assert.same(1, call_count)
    end)
  end)

  describe('use_unmount', function()
    it('registers callback for later', function()
      local called = false
      hooks.use_unmount(function()
        called = true
      end)
      -- Should not be called yet
      assert.is_false(called)
    end)

    it('callback runs when _run_unmount_callbacks called', function()
      local called = false
      hooks.use_unmount(function()
        called = true
      end)
      hooks._run_unmount_callbacks(instance)
      assert.is_true(called)
    end)

    it('multiple unmount callbacks all run', function()
      local calls = {}
      hooks.use_unmount(function()
        table.insert(calls, 1)
      end)
      hooks.use_unmount(function()
        table.insert(calls, 2)
      end)
      hooks._run_unmount_callbacks(instance)
      assert.same({ 1, 2 }, calls)
    end)

    it('updates callback if called again on re-render', function()
      local value = 'first'
      hooks.use_unmount(function()
        value = 'unmount1'
      end)

      -- Simulate re-render with different callback
      instance._hook_index = 1
      hooks.use_unmount(function()
        value = 'unmount2'
      end)

      hooks._run_unmount_callbacks(instance)
      assert.same('unmount2', value)
    end)
  end)

  describe('context', function()
    it('errors when hook called outside context', function()
      hooks._clear_context()
      assert.has_error(function()
        hooks.use_state(1)
      end, 'Hooks can only be called during component render')
    end)
  end)
end)
