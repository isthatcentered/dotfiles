local M = {}

---@param params {bufnr: number, eslint_client: vim.lsp.Client?, oxlint_client: vim.lsp.Client?, cb: fun():nil}
function M.run(params)
  local function run_eslint_fix_all(cb)
    if not params.eslint_client then
      cb()
      return
    end

    params.eslint_client:request('workspace/executeCommand', {
      command = 'eslint.applyAllFixes',
      arguments = {
        {
          uri = vim.uri_from_bufnr(params.bufnr),
          version = vim.lsp.util.buf_versions[params.bufnr],
        },
      },
    }, function(err)
      if err then
        vim.print(err)
      end

      cb()
    end, params.bufnr)
  end

  local function run_oxlint_fix_all(cb)
    if not params.oxlint_client then
      cb()
      return
    end

    params.oxlint_client:exec_cmd({
      title = 'Apply Oxlint automatic fixes',
      command = 'oxc.fixAll',
      arguments = {
        {
          uri = vim.uri_from_bufnr(params.bufnr),
        },
      },
    }, { bufnr = params.bufnr }, function(err)
      if err then
        vim.print(err)
      end

      cb()
    end)
  end

  run_eslint_fix_all(function()
    run_oxlint_fix_all(params.cb)
  end)
end

return M
