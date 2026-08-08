local M = {}

---@param client vim.lsp.Client
function M.list_code_actions(client)
  return client.server_capabilities.codeActionProvider.codeActionKinds
end

---@param params {bufnr: number, client: vim.lsp.Client, kinds: string[], cb: fun(actions: any[]):nil}
function M.get_code_actions(params)
  local code_action_params = vim.lsp.util.make_position_params(0, params.client.offset_encoding)
  local diagnostics = vim.diagnostic.get(params.bufnr, {
    namespace = vim.lsp.diagnostic.get_namespace(params.client.id),
  })
  local lsp_diagnostics = vim.tbl_map(function(d)
    return {
      range = {
        start = {
          line = d.lnum,
          character = d.col,
        },
        ['end'] = {
          line = d.end_lnum,
          character = d.end_col,
        },
      },
      severity = d.severity,
      message = d.message,
      source = d.source,
      code = d.code,
      data = d.user_data and (d.user_data.lsp or {}),
    }
  end, diagnostics)

  params.client:request('textDocument/codeAction', {
    textDocument = code_action_params.textDocument,
    range = {
      start = code_action_params.position,
      ['end'] = code_action_params.position,
    },
    context = {
      only = params.kinds,
      triggerKind = 1, -- vim.lsp.protocol.CodeActionTriggerKind.Invoked
      diagnostics = lsp_diagnostics,
    },
  }, function(err, result)
    if err then
      vim.print { err = err }
    end

    local actions_matching_kind = vim.tbl_filter(function(action)
      return vim.tbl_contains(params.kinds, action.kind)
    end, result or {})

    result = actions_matching_kind

    params.cb(result)
  end)
end

---@param params {bufnr: number, client: vim.lsp.Client, actions: any[], cb: fun():nil}
function M.handle_code_actions(params)
  -- local keys = {}
  -- for i, action in pairs(params.actions) do
  --   keys[i] = {}
  --   for key, _ in pairs(action) do
  --     table.insert(keys[i], key)
  --   end
  -- end
  -- vim.print(keys)
  --
  -- vim.print(vim.tbl_map(function(action)
  --   return {
  --     kind = action.kind,
  --     title = action.title,
  --     isPreferred = action.isPreferred,
  --     edit = action.edit,
  --     command = action.command
  --   }
  -- end, params.actions))

  if #params.actions < 1 then
    params.cb()
  end

  for _, action in pairs(params.actions) do
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit, params.client.offset_encoding)
      params.cb()
    elseif action.command then
      local command = type(action.command) == 'table' and action.command or action

      params.client:request(
        'workspace/executeCommand',
        {
          command = command.command,
          arguments = command.arguments,
          workDoneToken = command.workDoneToken,
        }, --
        function(err)
          if err then
            vim.print(err)
            return
          end
          params.cb()
        end
      )
    else
      params.cb()
    end
  end
end

---@param params {bufnr: number, client: vim.lsp.Client, kinds: string[], cb: fun():nil}
function M.run_code_actions(params)
  M.get_code_actions {
    bufnr = params.bufnr,
    client = params.client,
    kinds = params.kinds,
    cb = function(actions)
      -- vim.print({kinds = params.kinds, actions})
      M.handle_code_actions {
        bufnr = params.bufnr,
        client = params.client,
        actions = actions,
        cb = function()
          params.cb()
        end,
      }
    end,
  }
end

return M
