local M = {}
local adding_plugins = false
local blink_build_pending = false

local specs = {
  {
    src = 'https://github.com/saghen/blink.lib',
    name = 'blink.lib',
    version = 'main',
  },
  {
    src = 'https://github.com/L3MON4D3/LuaSnip',
    name = 'LuaSnip',
    version = vim.version.range '2.*',
  },
  {
    src = 'https://github.com/saghen/blink.cmp',
    name = 'blink.cmp',
    version = 'main',
  },
  {
    src = 'https://github.com/folke/todo-comments.nvim',
    name = 'todo-comments.nvim',
    version = 'main',
  },
  {
    src = 'https://github.com/folke/which-key.nvim',
    name = 'which-key.nvim',
    version = 'main',
  },
  {
    src = 'https://github.com/johmsalas/text-case.nvim',
    name = 'text-case.nvim',
    version = 'main',
  },
  {
    src = 'https://github.com/karb94/neoscroll.nvim',
    name = 'neoscroll.nvim',
    version = 'master',
  },
  {
    src = 'https://github.com/mason-org/mason.nvim',
    name = 'mason.nvim',
    version = 'main',
  },
  {
    src = 'https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim',
    name = 'mason-tool-installer.nvim',
    version = 'main',
  },
  {
    src = 'https://github.com/windwp/nvim-ts-autotag',
    name = 'nvim-ts-autotag',
    version = 'main',
  },
  {
    src = 'https://github.com/nvim-mini/mini.nvim',
    name = 'mini.nvim',
    version = vim.version.range '*',
  },
  {
    src = 'https://github.com/stevearc/oil.nvim',
    name = 'oil.nvim',
    version = 'master',
  },
  {
    src = 'https://github.com/lukas-reineke/indent-blankline.nvim',
    name = 'indent-blankline.nvim',
    version = 'master',
  },
  {
    src = 'https://github.com/folke/persistence.nvim',
    name = 'persistence.nvim',
    version = 'main',
  },
  {
    src = 'https://github.com/nvim-treesitter/nvim-treesitter',
    name = 'nvim-treesitter',
    version = 'main',
  },
  {
    src = 'https://github.com/meanderingprogrammer/render-markdown.nvim',
    name = 'render-markdown.nvim',
    version = 'main',
  },
  {
    src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects',
    name = 'nvim-treesitter-textobjects',
    version = 'main',
  },
  {
    src = 'https://github.com/nvim-lua/plenary.nvim',
    name = 'plenary.nvim',
    version = 'master',
  },
  {
    src = 'https://github.com/MunifTanjim/nui.nvim',
    name = 'nui.nvim',
    version = 'main',
  },
  {
    src = 'https://github.com/nvim-tree/nvim-web-devicons',
    name = 'nvim-web-devicons',
    version = 'master',
  },
  {
    src = 'https://github.com/ibhagwan/fzf-lua',
    name = 'fzf-lua',
    version = 'main',
  },
  {
    src = 'https://github.com/nvim-neo-tree/neo-tree.nvim',
    name = 'neo-tree.nvim',
    version = 'v3.x',
  },
  {
    src = 'https://github.com/nvim-lualine/lualine.nvim',
    name = 'lualine.nvim',
    version = 'master',
  },
  {
    src = 'https://github.com/mrjones2014/smart-splits.nvim',
    name = 'smart-splits.nvim',
    version = 'master',
  },
  {
    src = 'https://github.com/sindrets/diffview.nvim',
    name = 'diffview.nvim',
    version = 'main',
  },
  {
    src = 'https://github.com/lewis6991/gitsigns.nvim',
    name = 'gitsigns.nvim',
    version = 'main',
  },
  {
    src = 'https://github.com/NeogitOrg/neogit',
    name = 'neogit',
    version = 'master',
  },
  {
    src = 'https://github.com/kdheepak/lazygit.nvim',
    name = 'lazygit.nvim',
    version = 'main',
  },
}

local function run_build(command, cwd)
  local result = vim.system(command, { cwd = cwd, text = true }):wait()
  if result.code ~= 0 then
    error(result.stderr)
  end
end

local function build_blink()
  vim.cmd.packadd 'blink.lib'
  vim.cmd.packadd 'blink.cmp'
  require('blink.cmp').build():pwait()
end

local function build_plugin(event)
  if event.data.kind ~= 'install' and event.data.kind ~= 'update' then
    return
  end

  local name = event.data.spec.name
  if name == 'LuaSnip' then
    run_build({ 'make', 'install_jsregexp' }, event.data.path)
  elseif name == 'blink.cmp' then
    if adding_plugins then
      blink_build_pending = true
    else
      build_blink()
    end
  elseif name == 'nvim-treesitter' then
    if not event.data.active then
      vim.cmd.packadd 'nvim-treesitter'
    end
    require('config.pack.treesitter').update()
  end
end

local function setup_blink()
  require('blink.cmp').setup {
    keymap = {
      preset = 'enter',
      ['<C-s>'] = {
        function(cmp)
          cmp.show()
        end,
      },
      ['<C-a>'] = {
        function(cmp)
          cmp.show_signature()
        end,
      },
    },

    completion = {
      menu = {
        auto_show = true,
        border = 'rounded',
        draw = {
          columns = { { 'label', 'label_description', gap = 1 }, { 'kind_icon', 'kind', gap = 1 } },
          treesitter = { 'lsp' },
        },
      },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
        window = { border = 'rounded' },
      },
    },

    signature = {
      window = { border = 'rounded', show_documentation = true },
      enabled = true,
      trigger = {
        enabled = false,
        show_on_keyword = true,
        blocked_trigger_characters = {},
        blocked_retrigger_characters = {},
        show_on_trigger_character = true,
        show_on_insert = false,
        show_on_insert_on_trigger_character = true,
      },
    },

    snippets = { preset = 'luasnip' },
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer' },
    },
    fuzzy = { implementation = 'prefer_rust_with_warning' },
  }
end

local function setup_which_key()
  require('which-key').setup {
    delay = 0,
    icons = {
      mappings = vim.g.have_nerd_font,
      keys = vim.g.have_nerd_font and {} or {
        Up = '<Up> ',
        Down = '<Down> ',
        Left = '<Left> ',
        Right = '<Right> ',
        C = '<C-…> ',
        M = '<M-…> ',
        D = '<D-…> ',
        S = '<S-…> ',
        CR = '<CR> ',
        Esc = '<Esc> ',
        ScrollWheelDown = '<ScrollWheelDown> ',
        ScrollWheelUp = '<ScrollWheelUp> ',
        NL = '<NL> ',
        BS = '<BS> ',
        Space = '<Space> ',
        Tab = '<Tab> ',
        F1 = '<F1>',
        F2 = '<F2>',
        F3 = '<F3>',
        F4 = '<F4>',
        F5 = '<F5>',
        F6 = '<F6>',
        F7 = '<F7>',
        F8 = '<F8>',
        F9 = '<F9>',
        F10 = '<F10>',
        F11 = '<F11>',
        F12 = '<F12>',
      },
    },
    spec = {
      { '<leader>s', group = '[S]earch' },
      { '<leader>t', group = '[T]oggle' },
      { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
    },
  }
end

local function setup_mini()
  local spec_treesitter = require('mini.ai').gen_spec.treesitter

  require('mini.ai').setup {
    custom_textobjects = {
      f = spec_treesitter { a = '@function.outer', i = '@function.inner' },
      a = spec_treesitter { a = '@assignment.lhs', i = '@assignment.rhs' },
      P = spec_treesitter { a = '@parameter.inner', i = '@parameter.inner' },
      k = spec_treesitter { a = '@comment.outer', i = '@comment.inner' },
      c = spec_treesitter { a = '@call.outer', i = '@call.outer' },
    },
  }

  require('mini.pairs').setup {}
  require('mini.files').setup {}
  require('mini.icons').setup {}
end

local function setup_oil()
  require('oil').setup {
    view_options = {
      show_hidden = true,
      is_hidden_file = function()
        return false
      end,
    },
    watch_for_changes = true,
    lsp_file_methods = {
      enabled = true,
      timeout_ms = 20 * 1000,
    },
    preview_win = {
      preview_method = 'scratch',
    },
    keymaps = {
      ['<C-d>'] = { 'actions.preview_scroll_down' },
      ['<C-u>'] = { 'actions.preview_scroll_up' },
      ['<C-v>'] = { 'actions.select', opts = { vertical = true } },
      ['q'] = { 'actions.close', mode = 'n' },
    },
  }

  vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open file explorer' })
end

function M.add()
  vim.api.nvim_create_autocmd('PackChanged', {
    group = vim.api.nvim_create_augroup('native-plugin-builds', { clear = true }),
    callback = build_plugin,
  })

  adding_plugins = true
  vim.pack.add(specs, { confirm = false })
  adding_plugins = false

  if blink_build_pending then
    build_blink()
    blink_build_pending = false
  end
end

function M.setup()
  require('mason').setup {}
  require('mason-tool-installer').setup {
    ensure_installed = {
      'ast-grep',
      'jq',
      'biome',
      'eslint-lsp',
      'eslint_d',
      'goimports',
      'gopls',
      'json-lsp',
      'lua-language-server',
      'oxfmt',
      'oxlint',
      'prettier',
      'prettierd',
      'typescript-language-server',
      'vtsls',
      'emmet-language-server',
      'tailwindcss-language-server',
    },
  }

  setup_blink()
  setup_mini()
  setup_oil()
  require('nvim-web-devicons').setup {}
  require('config.pack.treesitter').setup()
  require('config.pack.neotree').setup()
  require('config.pack.lualine').setup()
  require('config.pack.smart_splits').setup()
  require('config.pack.git').setup()
  vim.cmd.packadd 'lazygit.nvim'
  require('ibl').setup {
    scope = {
      enabled = false,
    },
  }
  require('neoscroll').setup {
    cursor_scrolls_alone = false,
    duration_multiplier = 0.4,
    hide_cursor = false,
  }
  require('persistence').setup {}
  require('textcase').setup {}

  vim.api.nvim_create_autocmd('VimEnter', {
    group = vim.api.nvim_create_augroup('native-plugin-setup', { clear = true }),
    once = true,
    callback = function()
      setup_which_key()
      require('config.pack.fzflua').setup()
    end,
  })
end

function M.setup_after_lazy()
  require('todo-comments').setup {}
  require('nvim-ts-autotag').setup {}
end

return M
