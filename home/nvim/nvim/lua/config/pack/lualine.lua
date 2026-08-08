local M = {}

local function acid_theme()
  local colors = require('acid').colors()
  local normal_styles = { fg = colors.white, bg = colors.primary }
  local inactive_styles = { fg = colors.primary, bg = colors.primary_light }

  return {
    normal = { x = normal_styles, c = normal_styles },
    inactive = { x = inactive_styles, c = inactive_styles },
  }
end

local LuaLine = {
  'nvim-lualine/lualine.nvim',
  config = function()
    local TestsStatus = require 'lualine_components.TestStatus'
    local ScopedStatus = require 'lualine_components.ScopedStatus'
    local lualine = require 'lualine'

    lualine.setup {
      options = {
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },
        theme = acid_theme,
      },
      sections = {
        lualine_a = {},
        lualine_b = {},
        -- lualine_c = { 'filename', 'filetype', 'progress', 'diagnostics', 'location' },
        lualine_c = {
          { 'filename', path = 1, shorting_target = 30 },
          {
            'diagnostics',
            sources = { 'nvim_diagnostic', 'coc' },
            sections = { 'error' },
            diagnostics_color = {
              error = 'DiagnosticError', -- Changes diagnostics' error color.
            },
            symbols = { error = 'E', warn = 'W', info = 'I', hint = 'H' },
            colored = true, -- Displays diagnostics status in color if set to true.
            update_in_insert = false, -- Update diagnostics in insert mode.
            always_visible = false, -- Show diagnostics even if there are none.
          },
        },
        lualine_x = {
          -- { 'filetype', colored = false },
          'location',
          {

            ScopedStatus,
            TestsStatus,
            is_active = true,
          },
        },
        lualine_y = {},
        lualine_z = {},
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { 'filename' },
        lualine_x = {
          'location',
          {
            ScopedStatus,
            TestsStatus,
            is_active = false,
          },
        },
        lualine_y = {},
        lualine_z = {},
      },
    }

    vim.api.nvim_create_autocmd('User', {
      group = vim.api.nvim_create_augroup('acid-lualine-theme', { clear = true }),
      pattern = 'AcidVariantChanged',
      desc = 'Rebuild Lualine with the active Acid color variant',
      callback = function()
        lualine.setup()
        lualine.refresh { force = true, scope = 'all' }
      end,
    })
  end,
}

function M.setup()
  LuaLine.config()
end

return M
