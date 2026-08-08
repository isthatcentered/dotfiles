--[[ DIAGNOSTICS ]]
---------------------
-- DIagnostics navigation
-- local pos_equal = function (p1, p2)
--   local r1, c1 = unpack(p1)
--   local r2, c2 = unpack(p2)
--   return r1 == r2 and c1 == c2
-- end
--
-- local goto_next_error_then_hint = function ()
--   local pos = vim.api.nvim_win_get_cursor(0)
--   vim.diagnostic.jump( {count= 1, float=true,severity=vim.diagnostic.severity.ERROR, wrap = true} )
--   local pos2 = vim.api.nvim_win_get_cursor(0)
--   if ( pos_equal(pos, pos2)) then
--     vim.diagnostic.goto_next( {wrap = true} )
--   end
-- end
-- local goto_prev_error_then_hint = function ()
--   local pos = vim.api.nvim_win_get_cursor(0)
--   vim.diagnostic.goto_prev( {severity=vim.diagnostic.severity.ERROR, wrap = true} )
--   local pos2 = vim.api.nvim_win_get_cursor(0)
--   if ( pos_equal(pos, pos2)) then
--     vim.diagnostic.goto_prev( {wrap = true} )
--   end
-- end
vim.keymap.set('n', '<M-k>', function()
  vim.diagnostic.jump { count = -1, float = true, wrap = true }
end, { desc = 'Previous Diagnostic', noremap = true })

vim.keymap.set('n', '<M-j>', function()
  vim.diagnostic.jump { count = 1, float = true, wrap = true }
end, { desc = 'Next Diagnostic', noremap = true })

-- Quickfix navigation
local function current_window_is_quickfix_item(quickfix, index)
  local item = quickfix.items[index]

  if not item or item.bufnr == 0 or item.lnum == 0 then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_col = cursor[2] + 1

  return item.bufnr == vim.api.nvim_get_current_buf() and item.lnum == cursor[1] and (item.col == 0 or item.col == cursor_col)
end

local function quickfix_state()
  return vim.fn.getqflist { idx = 0, items = 0, size = 0 }
end

local function go_to_next_quickfix()
  local quickfix = quickfix_state()

  if quickfix.size == 0 then
    vim.notify('Quickfix list is empty', vim.log.levels.WARN)
    return
  end

  if quickfix.idx < 1 then
    vim.cmd 'cfirst'
    return
  end

  if not current_window_is_quickfix_item(quickfix, quickfix.idx) then
    vim.cmd('cc ' .. quickfix.idx)
    return
  end

  if quickfix.idx == quickfix.size then
    vim.cmd 'cfirst'
  else
    vim.cmd 'cnext'
  end
end

local function go_to_previous_quickfix()
  local quickfix = quickfix_state()

  if quickfix.size == 0 then
    vim.notify('Quickfix list is empty', vim.log.levels.WARN)
    return
  end

  if quickfix.idx < 1 then
    vim.cmd 'clast'
    return
  end

  if not current_window_is_quickfix_item(quickfix, quickfix.idx) then
    vim.cmd('cc ' .. quickfix.idx)
    return
  end

  if quickfix.idx == 1 then
    vim.cmd 'clast'
  else
    vim.cmd 'cprevious'
  end
end

vim.keymap.set('n', '<M-h>', go_to_previous_quickfix, { desc = 'Previous Quickfix' })
vim.keymap.set('n', '<M-l>', go_to_next_quickfix, { desc = 'Next Quickfix' })

-- TODO: Use onPublishDiagnostics to cap eslint max severity. This avoids having to override every sign handler

-- local originalPublishDiagnosticsHandler = vim.lsp.diagnostic.on_publish_diagnostics
-- vim.lsp.diagnostic.on_publish_diagnostics = function (...)
--   vim.print(...)
--   originalPublishDiagnosticsHandler(...)
--
-- end

-- local originalOnPublishDiagnosticsLSPHandler = vim.lsp.handlers['textDocument/publishDiagnostics']
-- vim.lsp.handlers['textDocument/publishDiagnostics'] = function(err, result, ctx)
--   local client = vim.lsp.get_client_by_id(ctx.client_id)
--
--   if not client then
--     return
--   end
--   vim.print { name = client.name, isEslint = client.name == 'eslint', result, ctx }
--   if not client or client.name ~= 'eslint' then
--     return originalOnPublishDiagnosticsLSPHandler(err, result, ctx)
--   end
--
--   -- vim.print({err, result, ctx})
--   return originalOnPublishDiagnosticsLSPHandler(err, result, ctx)
-- end
--
-- local autoCommandsGroup = vim.api.nvim_create_augroup('isthatcentered-lsp', { clear = true })
--
-- vim.api.nvim_create_autocmd('LspAttach', {
--   group = autoCommandsGroup,
--   callback = function(args)
--     if not args.data and not args.data.client_id then
--       return
--     end
--
--     local client = vim.lsp.get_client_by_id(args.data.client_id)
--     local bufnr = args.buf
--
--     if not client or client.name ~= 'eslint' then
--       return
--     end
--   end,
-- })
--
local ns = vim.api.nvim_create_namespace 'isthatcentered-diagnostics'

---@param diagnostic vim.Diagnostic
---@return boolean
local function isLint(diagnostic)
  return diagnostic.source == 'eslint'
end

---@alias DiagnosticTransform function(diagnostic: vim.Diagnostic): vim.Diagnostic?

---@param severity vim.diagnostic.Severity
local function onlyDiagnosticsOfSeverity(severity)
  ---@type DiagnosticTransform
  return function(diagnostic)
    if diagnostic.severity == severity then
      return diagnostic
    else
      return nil
    end
  end
end

---@param original_handler any
---@param customizeDiagnostics DiagnosticTransform[]
---@return any
local function withCustomizedDiagnostics(original_handler, customizeDiagnostics)
  return {
    show = function(_, bufnr, _, opts)
      -- Get all diagnostics from the whole buffer rather than just the
      -- diagnostics passed to the handler
      local diagnostics = vim.diagnostic.get(bufnr)
      local it = vim.iter(diagnostics)

      for _, transformer in pairs(customizeDiagnostics) do
        it:map(transformer)
      end

      it:filter(function(diagnostic)
        return diagnostic
      end)

      local transformedDiagnostics = it:totable()

      table.sort(transformedDiagnostics, function(a, b)
        return a.severity < b.severity
      end)

      original_handler.show(ns, bufnr, transformedDiagnostics, opts)
    end,
    hide = function(_, bufnr)
      original_handler.hide(ns, bufnr)
    end,
  }
end

--
-- -- vim.diagnostic.handlers.float = withCustomizedDiagnostics(vim.diagnostic.handlers.float, {
-- --   changelintDiagnosticsSeverity, --
-- -- })
-- vim.diagnostic.handlers.signs = withCustomizedDiagnostics(vim.diagnostic.handlers.signs, {
--   -- changelintDiagnosticsSeverity, --
-- })
-- vim.diagnostic.handlers.underline = withCustomizedDiagnostics(vim.diagnostic.handlers.underline, {
--   -- changelintDiagnosticsSeverity, --
-- })
-- vim.diagnostic.handlers.virtual_text = withCustomizedDiagnostics(vim.diagnostic.handlers.virtual_text, {
--   -- changelintDiagnosticsSeverity,
--   -- onlyDiagnosticsOfSeverity(vim.diagnostic.severity.ERROR), --
-- })

---@type DiagnosticTransform
local function changelintDiagnosticsSeverity(diagnostic)
  if isLint(diagnostic) then
    local modifiedDiagnostic = vim.tbl_extend('keep', { severity = vim.diagnostic.severity.WARN }, diagnostic)
    return modifiedDiagnostic
  end

  return diagnostic
end

local originalHandler = vim.lsp.handlers['textDocument/diagnostic']
vim.lsp.handlers['textDocument/diagnostic'] = function(err, result, ctx, options)
  -- vim.print(vim.diagnostic.get_namespaces())
  if err then
    vim.print(err)
  end

  result = result or {}
  for _, diagnostic in ipairs(result.items or {}) do
    if isLint(diagnostic) then
      diagnostic.severity = vim.diagnostic.severity.WARN
    end
  end
  -- local modifiedDiagnostics = vim
  --   .iter(diagnostics)
  --   :map(changelintDiagnosticsSeverity)
  --   :totable()
  --
  -- result.items = modifiedDiagnostics
  originalHandler(err, result, ctx, options)
end

vim.diagnostic.config {
  virtual_lines = false,
  virtual_text = {
    severity = { 'ERROR' },
  },
  underline = true,
  severity_sort = true,
  jump = { float = true },
  float = {
    source = true, --
    border = 'rounded',
    severity_sort = true,
    scope = 'cursor',
  },
  signs = {
    severity_sort = true,
    text = {
      [vim.diagnostic.severity.ERROR] = '',
      [vim.diagnostic.severity.WARN] = '',
      [vim.diagnostic.severity.INFO] = '',
      [vim.diagnostic.severity.HINT] = '',
    },
    linehl = {},
    numhl = {
      -- [vim.diagnostic.severity.ERROR] = 'DiagnosticLineNumberError',
      -- [vim.diagnostic.severity.WARN] = 'DiagnosticLineNumberWarn',
      -- [vim.diagnostic.severity.INFO] = 'DiagnosticLineNumberInfo',
      -- [vim.diagnostic.severity.HINT] = 'DiagnosticLineNumberHint',
    },
  },
}

vim.keymap.set('n', '<leader>td', function()
  local previous_config = vim.diagnostic.config()
  if not previous_config then
    return
  end

  vim.diagnostic.config {
    virtual_lines = not previous_config.virtual_lines, --
    -- virtual_text = not previous_config.virtual_text,
    -- underline = not previous_config.underline,
  }
end, { desc = 'Toggle diagnostic virtual_lines' })
