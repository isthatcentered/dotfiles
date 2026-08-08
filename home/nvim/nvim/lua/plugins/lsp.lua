local LazyDev = {
  'folke/lazydev.nvim',
  ft = 'lua', -- only load on lua files
  opts = {
    library = {
      -- See the configuration section for more details
      -- Load luvit types when the `vim.uv` word is found
      { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
    },
  },
}
local Refactoring = {
  'ThePrimeagen/refactoring.nvim',
  lazy = false,
  config = function()
    require('refactoring').setup()
    -- vim.keymap.set("x", "gre", ":Refactor extract ")
    -- vim.keymap.set("x", "", ":Refactor extract_to_file ")

    vim.keymap.set('x', 'gre', ':Refactor extract_var ')

    vim.keymap.set({ 'n' }, 'gri', ':Refactor inline_var')

    -- vim.keymap.set( "n", "<leader>rI", ":Refactor inline_func")

    -- vim.keymap.set("n", "<leader>rb", ":Refactor extract_block")
    -- vim.keymap.set("n", "<leader>rbf", ":Refactor extract_block_to_file")
  end,
}
local VTSLS = { 'yioneko/nvim-vtsls' }
local LANGUAGE_SERVERS = {
  'ast-grep',
  'biome',
  'eslint-lsp',
  'eslint_d',
  'goimports',
  'gopls',
  'oxfmt',
  'oxlint',
  'prettier',
  'prettierd',
  'typescript-language-server',
  'vtsls',
  'emmet-language-server',
  'tailwindcss-language-server',
}

local LSP = {
  'neovim/nvim-lspconfig',
  -- commit = '782dda984da54e465dcc142544133606139d0306',
  dependencies = {
    -- Useful status updates for LSP.
    { 'j-hui/fidget.nvim', opts = {} },
  },
  config = function()
    require('luasnip.loaders.from_vscode').lazy_load {
      paths = { vim.fn.stdpath 'config' .. '/snippets' },
    }

    local language_servers = {
      'lua_ls',
      'eslint',
      'gopls',
      -- 'biome',
      'oxlint',
      'ts_ls',
      -- 'vtsls',
      'emmet_language_server',
      'jsonls',
    }

    local capabilities = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), require('lsp-file-operations').default_capabilities())

    capabilities.textDocument.completion.completionItem = {
      documentationFormat = { 'markdown', 'plaintext' },
      snippetSupport = true,
      preselectSupport = true,
      insertReplaceSupport = true,
      labelDetailsSupport = true,
      deprecatedSupport = true,
      commitCharactersSupport = true,
      tagSupport = { valueSet = { 1 } },
      resolveSupport = {
        properties = {
          'documentation',
          'detail',
          'additionalTextEdits',
        },
      },
    }

    vim.lsp.config('*', { capabilities = capabilities })
    require('lspconfig.configs').vtsls = require('vtsls').lspconfig
    vim.lsp.config('vtsls', {
      ---@type lspconfig.settings.vtsls
      settings = {
        vtsls = {
          enableMoveToFileCodeAction = true,
          autoUseWorkspaceTsdk = true,
        },
        typescript = {
          tsserver = {
            maxTsServerMemory = 4000,
          },
          updateImportsOnFileMove = {
            enabled = 'always',
          },
          referencesCodeLens = {
            enabled = true,
            showOnAllFunctions = true,
            showOnInterfaceMethods = true,
          },
          preferences = {
            useAliasesForRenames = false,
            importModuleSpecifier = 'non-relative',
            preferTypeOnlyAutoImports = false,
          },
        },
      },
    })

    vim.lsp.config('lua_ls', {
      settings = {
        Lua = {
          workspace = {
            checkThirdParty = false,
            ignoreDir = { '__lua__', '.git', 'node_modules', '.dist', '.temp' },
          },
          telemetry = { enable = false },
        },
      },
    })

    local eslint_config_files = {
      '.eslintrc',
      '.eslintrc.js',
      '.eslintrc.cjs',
      '.eslintrc.yaml',
      '.eslintrc.yml',
      '.eslintrc.json',
      'eslint.config.js',
      'eslint.config.mjs',
      'eslint.config.cjs',
      'eslint.config.ts',
      'eslint.config.mts',
      'eslint.config.cts',
    }

    local function package_json_declares_eslint(package_json)
      local ok, contents = pcall(vim.fn.readfile, package_json)
      if not ok then
        return false
      end

      local ok_decode, package = pcall(vim.json.decode, table.concat(contents, '\n'))
      if not ok_decode or type(package) ~= 'table' then
        return false
      end

      for _, dependency_key in ipairs { 'dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies' } do
        local dependencies = package[dependency_key]
        if type(dependencies) == 'table' and dependencies.eslint then
          return true
        end
      end

      return false
    end

    vim.lsp.config('eslint', {
      root_dir = function(bufnr, on_dir)
        if vim.fs.root(bufnr, { 'deno.json', 'deno.jsonc', 'deno.lock' }) then
          return
        end

        local filename = vim.api.nvim_buf_get_name(bufnr)
        local config_file = vim.fs.find(eslint_config_files, {
          path = filename,
          type = 'file',
          limit = 1,
          upward = true,
        })[1]
        if not config_file then
          return
        end

        local package_json = vim.fs.find('package.json', {
          path = filename,
          type = 'file',
          limit = 1,
          upward = true,
        })[1]
        if not package_json or not package_json_declares_eslint(package_json) then
          return
        end

        on_dir(vim.fs.dirname(package_json))
      end,
    })

    vim.lsp.config('ts_ls', {
      settings = {
        supportsMoveToFileCodeAction = true,
        typescript = {
          updateImportsOnFileMove = {
            enabled = 'always',
          },
        },
        -- https://github.com/typescript-language-server/typescript-language-server/blob/master/docs/configuration.md#preferences-options
        preferences = {
          importModuleSpecifierPreference = 'relative',
          maximumHoverLength = 1000,
        },
      },
      init_options = {
        supportsMoveToFileCodeAction = true,
        -- https://github.com/typescript-language-server/typescript-language-server/blob/master/docs/configuration.md#preferences-options
        preferences = {
          importModuleSpecifierPreference = 'relative',
          maximumHoverLength = 1000,
        },
      },
    })

    vim.lsp.commands['editor.action.showReferences'] = function(command, ctx)
      local locations = command.arguments[3]
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if locations and #locations > 0 then
        local items = vim.lsp.util.locations_to_items(locations, client.offset_encoding)
        vim.fn.setloclist(0, {}, ' ', { title = 'References', items = items, context = ctx })
        vim.api.nvim_command 'lopen'
      end
    end

    for _, ls in pairs(language_servers) do
      vim.lsp.enable(ls)
    end

    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc, mode)
          mode = mode or 'n'
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        map('grr', vim.lsp.buf.rename, '[R]efactor [R]ename')

        map('gra', vim.lsp.buf.code_action, '[R]efactor [A]ctions', { 'n', 'x' })

        map('glr', function()
          require('fzf-lua').lsp_references()
        end, '[L]ens [R]eferences')

        map('gli', function()
          require('fzf-lua').lsp_implementations()
        end, '[L]ens [I]mplementation')

        --  To jump back, press <C-t>.
        map('gld', function()
          require('fzf-lua').lsp_definitions()
        end, '[G]oto [D]efinition')

        -- WARN: This is not Goto Definition, this is Goto Declaration.
        --  For example, in C this would take you to the header.
        map('glD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        map('gls', require('fzf-lua').lsp_document_symbols, '[L]ens [S]ymbols')

        map('glws', require('fzf-lua').lsp_live_workspace_symbols, '[L]ens [W]orkspace [S]ymbols')

        -- Jump to the type of the word under your cursor.
        --  Useful when you're not sure what type a variable is and you want to see
        --  the definition of its *type*, not where it was *defined*.
        map('glt', require('fzf-lua').lsp_typedefs, '[G]oto [T]ype Definition')

        -- vim.print(vim.fn.getcompletion('@lsp', 'highlight'))
        -- for _, group in ipairs(vim.fn.getcompletion('@lsp', 'highlight')) do
        --   vim.api.nvim_set_hl(0, group, {})
        -- end

        -- Highlight word under cursor
        --
        -- local original_handler = vim.lsp.handlers['textDocument/rename']
        -- vim.lsp.handlers['textDocument/rename'] = function(err, method, result, ...)
        --   vim.print 'Calling rename'
        --   original_handler(err, method, result, ...)
        --   vim.print 'Reame done:::'
        -- end
        --

        local client = vim.lsp.get_client_by_id(event.data.client_id)

        if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_foldingRange, event.buf) then
          vim.wo.foldexpr = 'v:lua.vim.lsp.foldexpr()'
        end

        if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
          local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        map('<leader>th', function()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
        end, '[T]oggle Inlay [H]ints')
      end,
    })
  end,
}

return {
  VTSLS,
  LazyDev,
  LSP,
}
