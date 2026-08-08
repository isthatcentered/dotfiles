local ShowKeys = {
  'nvzone/showkeys',
  cmd = 'ShowkeysToggle',
  opts = {
    timeout = 6,
    maxkeys = 4,
    position = 'top-center',
    -- more opts
  },
}

local Leap = {
  'ggandor/leap.nvim',
  config = function()
    require('leap').setup {}
    vim.keymap.set({ 'n', 'x', 'o' }, 's', '<Plug>(leap-forward)')
    vim.keymap.set({ 'n', 'x', 'o' }, 'S', '<Plug>(leap-backward)')
    vim.keymap.set('n', 'gs', '<Plug>(leap-from-window)')
  end,
}

local copilot = { 'github/copilot.vim' }

local Harpoon = {

  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local harpoon = require 'harpoon'
    local harpoon_extensions = require 'harpoon.extensions'

    harpoon:setup()

    harpoon:extend(harpoon_extensions.builtins.highlight_current_file())

    -- Default list
    vim.keymap.set('n', '<leader>haa', function()
      harpoon:list():add()
    end, { desc = 'Add to main list' })

    vim.keymap.set('n', '<leader><leader>', function()
      harpoon.ui:toggle_quick_menu(harpoon:list())
    end, { desc = 'Show main list' })

    vim.keymap.set('n', '<leader>hax', function()
      harpoon:list():clear()
    end, { desc = 'Clear main list' })

    -- Alt list
    local alt_list_name = 'alt'
    vim.keymap.set('n', '<leader>hba', function()
      harpoon:list(alt_list_name):add()
    end, { desc = 'Add to alternative list' })

    vim.keymap.set('n', '<leader>hbl', function()
      harpoon.ui:toggle_quick_menu(harpoon:list(alt_list_name))
    end, { desc = 'Show alternative list' })

    vim.keymap.set('n', '<leader>hbx', function()
      harpoon:list(alt_list_name):clear()
    end, { desc = 'Clear alternative list' })

    -- vim.keymap.set('n', '<C-h>', function()
    --   harpoon:list():select(1)
    -- end)
    -- vim.keymap.set('n', '<C-t>', function()
    --   harpoon:list():select(2)
    -- end)
    -- vim.keymap.set('n', '<C-n>', function()
    --   harpoon:list():select(3)
    -- end)
    -- vim.keymap.set('n', '<C-s>', function()
    --   harpoon:list():select(4)
    -- end)
    --
    vim.keymap.set('n', '<C-k>', function()
      harpoon:list():prev()
    end)

    vim.keymap.set('n', '<C-j>', function()
      harpoon:list():next()
    end)

    vim.keymap.set('n', '<C-h>', ':b#<cr>', { desc = 'Go to alternate buffer' })

    harpoon:extend {
      UI_CREATE = function(cx)
        vim.keymap.set('n', '<C-v>', function()
          harpoon.ui:select_menu_item { vsplit = true }
        end, { buffer = cx.bufnr })

        vim.keymap.set('n', '<C-x>', function()
          harpoon.ui:select_menu_item { split = true }
        end, { buffer = cx.bufnr })

        vim.keymap.set('n', '<C-t>', function()
          harpoon.ui:select_menu_item { tabedit = true }
        end, { buffer = cx.bufnr })
      end,
    }
  end,
}

local Noice = {
  'folke/noice.nvim',
  event = 'VeryLazy',
  opts = {
    -- add any options here
  },
  dependencies = {
    -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
    'MunifTanjim/nui.nvim',
    -- OPTIONAL:
    --   `nvim-notify` is only needed, if you want to use the notification view.
    --   If not available, we use `mini` as the fallback
    'rcarriga/nvim-notify',
  },
}

local NeoTree = {
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v3.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'nvim-tree/nvim-web-devicons', -- optional, but recommended
  },
  lazy = false, -- neo-tree will lazily load itself
}

return {
  -- NeoTree,
  -- ShowKeys,
  -- { 'NMAC427/guess-indent.nvim', opts = {} }, -- Detect tabstop and shiftwidth automatically
  -- Leap,
  -- {
  --   'catgoose/nvim-colorizer.lua',
  --   event = 'BufReadPre',
  --   opts = {},
  -- },
}
