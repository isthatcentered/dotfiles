local M = {}

---@generic A
---@class Async<A>
---@field fn fun(res: fun(arg: any))
local Async = {}
Async.__index = Async

---@generic A
---@param fn fun(res: fun(value: A))
---@return Async<A>
function Async.new(fn)
  return setmetatable({
    fn = fn,
  }, Async)
end

function Async:chain(next)
  self.fn(next)
end

function M.setup()
  vim.print 'registered'

  vim.lsp.commands['_typescript.moveToFileRefactoring'] = function(command, defaultHandler)
    vim.print 'ACTIVATEDl:::'
    local client = vim.lsp.get_clients({ name = 'vtsls', bufnr = 0 })[1]
    command.targetFile = '/Users/edouardpenin/Test/random-ts-project-for-test/src/blah.ts'

    if not client then
      vim.notify('No vtsls client attached', vim.log.levels.ERROR)
      return
    end

    command.arguments[1].targetFile = '/Users/edouardpenin/Test/random-ts-project-for-test/src/blah2.ts'
    client:request('workspace/executeCommand', command, function(err, result, ctx, config)
      vim.print(err, result, ctx, config)
      if err then
        vim.notify('MoveToFileRefactoring failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
        return
      end
      if result then
        vim.lsp.handlers['workspace/executeCommand'](err, result, ctx, config)
      else
        vim.notify('No result from moveToFileRefactoring', vim.log.levels.WARN)
      end
    end, vim.api.nvim_get_current_buf())
  end
  -- local defaultWorkspaceActionHandler = vim.lsp.handlers['workspace/executeCommand']
  --
  -- vim.print("registered:::", defaultWorkspaceActionHandler)
  -- vim.lsp.handlers['workspace/executeCommand'] = function(err, method, result, ...)
  --   vim.print(err, method, result, ...)
  --   defaultWorkspaceActionHandler(err, method, result, ...)
  --   vim.print 'Overridden'
  -- end
  --
  vim.keymap.set('n', '<leader>y', function()
    local buffer_id = vim.api.nvim_get_current_buf()
    local ts_ls_client = vim.lsp.get_clients({ name = 'ts_ls' })[1]
    assert(ts_ls_client, 'TS_LS client not active for the current buffer')

    -- {
    --  command = {
    --    arguments = {
    --      { description = \"Move to file\", kind = \"refactor.move.file\", name = \"Move to file\", range = { [\"end\"] = { line = 19, offset = 55 }, start = { line = 16, offset = 1 } } },
    --      \"file:///Users/edouardpenin/Test/random-ts-project-for-test/src/index.ts\",
    --      { [\"end\"] = { character = 6, line = 15 }, start = { character = 6, line = 15 } }
    --    },
    --    command = \"_typescript.moveToFileRefactoring\",
    --    title = \"Move to file\" }, k
    --    data = { cacheId = 2, index = 0, providerId = 20 },
    --    isPreferred = false,
    --    kind = \"refactor.move.file\",
    --    title = \"Move to file\"
    -- }
    ts_ls_client:request('workspace/executeCommand', {
      command = '_typescript.moveToFileRefactoring',
      arguments = {
        {
          description = 'Move to file',
          kind = 'refactor.move.file',
          name = 'Move to file',
          range = {
            ['end'] = {
              line = 15, -- 1 indexed
              offset = 22, -- 1 indexed
            },
            start = {
              line = 15,
              offset = 0,
            },
          },
        },

        -- Original file
        'file:///Users/edouardpenin/Test/random-ts-project-for-test/src/index.ts',

        -- This is where the cursor is when asking for the refactor
        {
          start = {
            character = 6,
            line = 15,
          },
          ['end'] = {
            character = 6, -- 0 indexed
            line = 15, -- 0 indexed
          },
        },

        -- Target
        '/Users/edouardpenin/Test/random-ts-project-for-test/src/blah.ts',
      },
    }, function(err, result, ctx, config)
      vim.print { err, result }
    end, buffer_id)

    -- local lspParams = vim.lsp.util.make_position_params(0, 'utf-8')
    -- vim.print(lspParams)
    -- lspParams.newName = 'new_name'
    --
    -- vim.lsp.buf_request(0, 'textDocument/rename', lspParams, function(err, method, result, ...)
    --   print(err, method, result)
    --   vim.lsp.handlers['textDocument/rename'](err, method, result, ...)
    --   vim.print 'Renaming done'
    -- end)
  end)
end

M.setup()

-- TextCaseOpenTelescope
local blah = 1234
