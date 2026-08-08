local usedVariable = ""
local unusedVariable = ""
local function unusedFunction()
  vim.print(usedVariable)
end

local async = require("beacon.async")

local SymbolIdByName = {
  File = 1,
  Module = 2,
  Namespace = 3,
  Package = 4,
  Class = 5,
  Method = 6,
  Property = 7,
  Field = 8,
  Constructor = 9,
  Enum = 10,
  Interface = 11,
  Function = 12,
  Variable = 13,
  Constant = 14,
  String = 15,
  Number = 16,
  Boolean = 17,
  Array = 18,
  Object = 19,
  Key = 20,
  Null = 21,
  EnumMember = 22,
  Struct = 23,
  Event = 24,
  Operator = 25,
  TypeParameter = 26,
}

---@type {number: string}
local SymbolNameById = {}
for symbolName, symbolId in pairs(SymbolIdByName) do
  SymbolNameById[symbolId] = symbolName
end

local M = {}

---@param symbol lsp.DocumentSymbol
---@return boolean
local function isRelevantSymbol(symbol)
  return not vim.tbl_contains({
    SymbolIdByName.Package,
  }, symbol.kind)
end

---@async
---@param client vim.lsp.Client
---@return {error?: string, results: lsp.DocumentSymbol[]}
function list_document_symbols(client)
  return async.supend(function(done)
    client:request(
      "textDocument/documentSymbol",
      { textDocument = vim.lsp.util.make_text_document_params() },
      function(err, results, context, options)
        done({ error = err, symbols = results })
      end
    )
  end)
end

---@async
---@param params {client: vim.lsp.Client, buffer_id: integer, position: lsp.Position, include_declaration: boolean}
---@return {error?: string, references: unknown}
function list_references(params)
  return async.suspend(function(done)
    params.client:request(
      "textDocument/references",
      {
        textDocument = vim.lsp.util.make_text_document_params(params.buffer_id),
        position = { line = params.position.line, character = params.position.character },
        context = { includeDeclaration = params.include_declaration },
      }, --
      function(err, results, context, config)
        done({ error = err, references = results })
      end
    )
  end)
end

-- TODO: Run on buffer loaded && insert exit/buffer changed (is there an lsp event for this ?)
local beacon_namespace = vim.api.nvim_create_namespace("beacon-diagnostics")
local beacon_group = vim.api.nvim_create_augroup("beacon-commands", { clear = true })

local function do_the_stuff(BUFFER_ID)
  vim.diagnostic.reset(beacon_namespace, BUFFER_ID)
  -- vim.api.nvim_clear_autocmds({group = beacon_group})

  local bufferClients = vim.lsp.get_clients({
    bufnr = BUFFER_ID,
    method = "textDocument/documentSymbol",
  })

  for _, client in pairs(bufferClients) do
    client:request(
      "textDocument/documentSymbol",
      { textDocument = vim.lsp.util.make_text_document_params() },
      function(err, symbols, context, options)
        symbols = symbols or {}
        -- vim.print(results)
        ---@type lsp.DocumentSymbol[]
        local relevant_symbols = vim.tbl_filter(function(symbol)
          -- vim.print({ given = SymbolNameById[symbol.kind], name = symbol.name, kind = symbol.kind })
          return isRelevantSymbol(symbol)
        end, symbols)

        -- vim.print(relevant_symbols)

        for _, symbol in pairs(relevant_symbols) do
          client:request(
            "textDocument/references",
            {
              textDocument = vim.lsp.util.make_text_document_params(),
              position = { line = symbol.range.start.line, character = symbol.range.start.character },
              context = { includeDeclaration = false },
            }, --
            function(err, references, context, config)
              references = references or {}
              -- if symbol.name == "do_the_stuff" then
              --   vim.print({
              --     kept = SymbolNameById[symbol.kind],
              --     results = results,
              --     name = symbol.name,
              --     has_references = #results > 0,
              --   })
              -- end
              local is_used = #references > 0
              if is_used then
                return
              end

              local definitionLine =
                vim.api.nvim_buf_get_lines(BUFFER_ID, symbol.range.start.line, symbol.range.start.line + 1, false)[1]

              if not definitionLine then
                return
              end

              local nameStart, nameEnd = string.find(definitionLine, symbol.name)

              if nameStart == nil then
                -- Line has been deleted since we requested the references
                return
              end

              --TODO: Add symbol in gutter for unused
              local diagnostics = vim.diagnostic.get(BUFFER_ID, { namespace = beacon_namespace })
              table.insert(diagnostics, {
                severity = vim.diagnostic.severity.WARN,
                col = nameStart - 1,
                end_col = nameEnd,
                lnum = symbol.range.start.line,
                end_lnum = symbol.range.start.line,
                message = 'Unused symbol "' .. symbol.name .. '"' .. '("' .. SymbolNameById[symbol.kind] .. '")',
                source = "Beacon",
              })
              vim.diagnostic.set(beacon_namespace, BUFFER_ID, diagnostics, {})
            end
          )
        end
      end
    )
  end
end

function M.register()
  vim.api.nvim_create_autocmd({ "LspAttach" }, {
    group = beacon_group,
    callback = function(event)
      -- vim.print(event)
      local buffer_id = event.buf
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      assert(client, "Client not found")
      -- vim.print({client_name = client.name, client.initialized})
      do_the_stuff(buffer_id)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    group = beacon_group,
    callback = function(event)
      local buffer_id = event.buf
      do_the_stuff(buffer_id)
    end,
  })
end

return M
-- register()

-- vim.diagnostic.set(vim.api.nvim_create_namespace("blah"), 0, {
--   {
--     severity = 1,
--     col = 6,
--     end_col = 20,
--     lnum = 1,
--     end_lnum = 1,
--     source = "blah",
--     message = "fuuuuck",
--   },
-- }, {})
