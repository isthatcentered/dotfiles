local lint_fixers_module = 'isthatcentered.lint_fixers'

local function reload_lint_fixers()
  package.loaded[lint_fixers_module] = nil
  return require(lint_fixers_module)
end

local function create_test_buffer()
  local path = vim.fn.tempname() .. '.ts'

  vim.fn.writefile({ 'const value = 1' }, path)
  vim.cmd('edit ' .. vim.fn.fnameescape(path))

  return vim.api.nvim_get_current_buf(), path
end

describe('isthatcentered.lint_fixers', function()
  after_each(function()
    for _, buffer_id in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buffer_id) and vim.bo[buffer_id].buflisted then
        local name = vim.api.nvim_buf_get_name(buffer_id)

        if name ~= '' and name:find(vim.loop.os_tmpdir(), 1, true) == 1 then
          vim.api.nvim_buf_delete(buffer_id, { force = true })
          os.remove(name)
        end
      end
    end
  end)

  it('runs oxlint even when eslint is not attached', function()
    local lint_fixers = reload_lint_fixers()
    local buffer_id = create_test_buffer()
    local calls = {}
    local callback_ran = false

    vim.lsp.util.buf_versions[buffer_id] = 3

    lint_fixers.run {
      bufnr = buffer_id,
      eslint_client = nil,
      oxlint_client = {
        exec_cmd = function(_, command, context, cb)
          table.insert(calls, {
            kind = 'oxlint',
            command = command.command,
            uri = command.arguments[1].uri,
            bufnr = context.bufnr,
          })
          cb(nil)
        end,
      },
      cb = function()
        callback_ran = true
      end,
    }

    assert.same({
      {
        kind = 'oxlint',
        command = 'oxc.fixAll',
        uri = vim.uri_from_bufnr(buffer_id),
        bufnr = buffer_id,
      },
    }, calls)
    assert.is_true(callback_ran)
  end)

  it('runs eslint even when oxlint is not attached', function()
    local lint_fixers = reload_lint_fixers()
    local buffer_id = create_test_buffer()
    local calls = {}
    local callback_ran = false

    vim.lsp.util.buf_versions[buffer_id] = 7

    lint_fixers.run {
      bufnr = buffer_id,
      eslint_client = {
        request = function(_, method, params, cb, request_bufnr)
          table.insert(calls, {
            kind = 'eslint',
            method = method,
            command = params.command,
            uri = params.arguments[1].uri,
            version = params.arguments[1].version,
            bufnr = request_bufnr,
          })
          cb(nil)
        end,
      },
      oxlint_client = nil,
      cb = function()
        callback_ran = true
      end,
    }

    assert.same({
      {
        kind = 'eslint',
        method = 'workspace/executeCommand',
        command = 'eslint.applyAllFixes',
        uri = vim.uri_from_bufnr(buffer_id),
        version = 7,
        bufnr = buffer_id,
      },
    }, calls)
    assert.is_true(callback_ran)
  end)

  it('runs eslint before oxlint when both are attached', function()
    local lint_fixers = reload_lint_fixers()
    local buffer_id = create_test_buffer()
    local calls = {}
    local callback_ran = false

    vim.lsp.util.buf_versions[buffer_id] = 11

    lint_fixers.run {
      bufnr = buffer_id,
      eslint_client = {
        request = function(_, method, params, cb)
          table.insert(calls, {
            kind = 'eslint',
            method = method,
            command = params.command,
          })
          cb(nil)
        end,
      },
      oxlint_client = {
        exec_cmd = function(_, command, _, cb)
          table.insert(calls, {
            kind = 'oxlint',
            command = command.command,
          })
          cb(nil)
        end,
      },
      cb = function()
        callback_ran = true
      end,
    }

    assert.same({
      {
        kind = 'eslint',
        method = 'workspace/executeCommand',
        command = 'eslint.applyAllFixes',
      },
      {
        kind = 'oxlint',
        command = 'oxc.fixAll',
      },
    }, calls)
    assert.is_true(callback_ran)
  end)
end)
