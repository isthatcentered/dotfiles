local debounce = require("nope.debounce")

describe("debounce", function()
  it("calls function after delay", function()
    local called = false
    local debounced, cancel = debounce(function()
      called = true
    end, 50)

    debounced()
    assert.is_false(called)

    vim.wait(100, function()
      return called
    end)
    assert.is_true(called)
    cancel()
  end)

  it("resets timer on repeated calls", function()
    local call_count = 0
    local debounced, cancel = debounce(function()
      call_count = call_count + 1
    end, 50)

    debounced()
    vim.wait(30, function() return false end)
    debounced()
    vim.wait(30, function() return false end)
    debounced()

    vim.wait(100, function()
      return call_count > 0
    end)

    assert.same(1, call_count)
    cancel()
  end)

  it("cancel prevents execution", function()
    local called = false
    local debounced, cancel = debounce(function()
      called = true
    end, 50)

    debounced()
    cancel()

    vim.wait(100, function() return false end)
    assert.is_false(called)
  end)

  it("passes arguments correctly", function()
    local received_args = nil
    local debounced, cancel = debounce(function(a, b, c)
      received_args = { a, b, c }
    end, 50)

    debounced("foo", 42, { key = "value" })

    vim.wait(100, function()
      return received_args ~= nil
    end)

    assert.same({ "foo", 42, { key = "value" } }, received_args)
    cancel()
  end)

  it("uses latest arguments when called multiple times", function()
    local received_args = nil
    local debounced, cancel = debounce(function(a)
      received_args = a
    end, 50)

    debounced("first")
    debounced("second")
    debounced("third")

    vim.wait(100, function()
      return received_args ~= nil
    end)

    assert.same("third", received_args)
    cancel()
  end)

  it("can be called again after firing", function()
    local call_count = 0
    local debounced, cancel = debounce(function()
      call_count = call_count + 1
    end, 30)

    debounced()
    vim.wait(60, function()
      return call_count > 0
    end)
    assert.same(1, call_count)

    debounced()
    vim.wait(60, function()
      return call_count > 1
    end)
    assert.same(2, call_count)
    cancel()
  end)

  it("cancel is idempotent", function()
    local debounced, cancel = debounce(function() end, 50)

    debounced()
    cancel()
    cancel()
    cancel()
    -- Should not error
  end)
end)
