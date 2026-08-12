local M = {}

local CURRENT_VARIANT = "normal"
local DIMMED_OVERLAY = {
	fill = "#f0f3f4",
	opacity = 0.5,
}

local function normal_colors()
	return {
		white = "#ffffff",
		text = "#000000",
		blue = "#0488DB",
		green = "#0BA463",
		darkGray = "#313131",
		swampGreen = "#006564",
		acidGreen = "#00db9c",
		gold = "#6f0000",
		gray_4 = "#5D5D5D",
		gray_3 = "#A8A8A8",
		gray_2 = "#a5b7c5",
		gray_1 = "#e9f0f7",
		gray_0 = "#f7f8fa",
		markdown_code = "#f6f8fa",
		markdown_code_inline = "#eff1f3",
		red = "#fa0000",
		orange = "#FF7E00",

		diff_red = "#ffeae6",
		diff_red_text = "#ffd0cd",
		-- color: #ffeae6;
		-- color: #e9f8ea;
		diff_green = "#e1f8e1",
		diff_green_text = "#d0f0d4",
		diff_missing = "#f5f5f5",

		secondary_light = "#ffe999",
		secondary = "#ffc500",
		primary = "#4c0095",
		primary_light = "#f0ebf9",
		-- primary = "#0000a4",
	}
end

local function blend_channel(color, fill, opacity)
	return math.floor(color * (1 - opacity) + fill * opacity + 0.5)
end

local function apply_overlay(color, overlay)
	if type(color) ~= "string" or not color:match("^#%x%x%x%x%x%x$") then
		return color
	end

	local red = tonumber(color:sub(2, 3), 16)
	local green = tonumber(color:sub(4, 5), 16)
	local blue = tonumber(color:sub(6, 7), 16)
	local fill_red = tonumber(overlay.fill:sub(2, 3), 16)
	local fill_green = tonumber(overlay.fill:sub(4, 5), 16)
	local fill_blue = tonumber(overlay.fill:sub(6, 7), 16)

	return string.format(
		"#%02x%02x%02x",
		blend_channel(red, fill_red, overlay.opacity),
		blend_channel(green, fill_green, overlay.opacity),
		blend_channel(blue, fill_blue, overlay.opacity)
	)
end

function M.colors(variant)
	variant = variant or CURRENT_VARIANT
	assert(variant == "normal" or variant == "dimmed", "Unknown Acid color variant: " .. variant)

	local colors = normal_colors()

	if variant == "dimmed" then
		for name, color in pairs(colors) do
			colors[name] = apply_overlay(color, DIMMED_OVERLAY)
		end
	end

	return colors
end

function M.current_variant()
	return CURRENT_VARIANT
end

function M.set_variant(variant)
	assert(variant == "normal" or variant == "dimmed", "Unknown Acid color variant: " .. variant)

	if CURRENT_VARIANT == variant then
		return
	end

	CURRENT_VARIANT = variant
	M.setup()

	vim.api.nvim_exec_autocmds("User", {
		pattern = "AcidVariantChanged",
		modeline = false,
		data = { variant = variant },
	})
end

function M.setup()
	local old_colors = {
		white = "#ffffff",
		text = "#000000",
		blue = "#0488DB",
		green = "#0BA463",
		darkGray = "#313131",
		swampGreen = "#458383",
		acidGreen = "#51E2B6",
		gold = "#914C07",
		gray_4 = "#5D5D5D",
		gray_3 = "#A8A8A8",
		gray_2 = "#CED7DF",
		gray_1 = "#e9f0f7",
		gray_0 = "#f7f8fa",
		red = "#F61067",
		orange = "#FF7E00",

		secondary_light = "#ffe999",
		secondary = "#ffd230",
		primary = "#5E04B3",
	}

	local colors = M.colors()

	-----------------------------------------------------
	-- :hi to list all applied highlight and their styles
	-----------------------------------------------------
	local highlights = {
		Normal = { fg = colors.text, bg = colors.white },
		Cursor = { bg = colors.primary, fg = colors.white },
		CursorLine = { bg = colors.gray_0 },
		MatchParen = { bg = colors.acidGreen },
		Visual = { bg = colors.secondary },
		Search = { link = "Visual" },
		CurSearch = { link = "Search" },
		-- VertSplit = { bg = colors.secondary }, -- Column separating vertically split windows
		NormalFloat = { bg = colors.white, fg = colors.text }, -- Normal text in floating windows.
		PMenu = { link = "Normal" },
		PMenuSel = { bg = colors.secondary, fg = colors.text },
		PMenuKindSel = { link = "PMenuSel" },
		PMenuThumb = { bg = colors.primary },
		FloatBorder = {}, -- Border of floating windows.
		VertSplit = { link = "Normal" },
		StatusLineNC = { bg = colors.primary, fg = colors.white },
		StatusLine = { bg = colors.primary_light, fg = colors.primary },
		Winseparator = { bg = colors.primary_light, fg = colors.primary }, -- Separator between window splits. Inherts from |hl-VertSplit| by default, which it will replace eventually.

		SpellBad = { strikethrough = true },

		-- Syntax
		Special = { link = "Normal" },
		Identifier = { link = "Normal" },
		Function = { link = "Normal" },
		Statement = { link = "Normal" },
		PreProc = { link = "Normal" },
		Type = { link = "Normal" },
		Constant = { link = "Normal" },
		Operator = { link = "Normal" },
		Delimiter = { link = "Normal" },

		Keyword = { fg = colors.primary, bold = true },
		["htmlTagName"] = { fg = colors.primary, bold = true },
		["tsxTagName"] = { link = "htmlTagName" },
		["typescriptExport"] = { fg = colors.primary, bold = true },
		["typescriptVariable"] = { fg = colors.primary, bold = true },
		["typescriptStatementKeyword"] = { fg = colors.primary, bold = true },
		-- Variable = { fg = colors.primary, bold = true },
		-- ["@lsp.type.method"] = { fg = colors.primary },
		-- ["@lsp.mod.declaration"] = { fg = colors.swampGreen, bold = false },
		["@variable"] = { fg = colors.swampGreen },
		["@variable.member"] = {},
		["@lsp.type.type"] = { fg = colors.primary, bold = true },
		["@constant.builtin"] = { fg = colors.primary, bold = true },
		-- ["@lsp.type.class"] = { fg = colors.primary, bold = true },
		["@variable.parameter"] = { link = "Normal" },
		["@lsp"] = {},
		["@lsp.type.function"] = {},
		["@lsp.type.property"] = {},
		["@lsp.type.method"] = { fg = colors.gold },
		["@function.method.call"] = { fg = colors.primary, bold = true },
		["@function.call"] = { italic = true, fg = colors.text },
		["@lsp.type.interface.typescript"] = { fg = colors.primary, bold = true },
		["@lsp.type.class"] = {},
		["@tag.tsx"] = { link = "htmlTagName" },
		["@tag.builtin"] = { link = "htmlTagName" },
		-- ["@lsp.mod.declaration"] = {fg = colors.text, bold = false},
		-- ["boolean"] = { fg = colors.primary, bold = true },
		-- ["keyword"] = { fg = colors.primary, bold = true },
		-- ["type"] = { fg = colors.primary, bold = true },
		-- ["type.builtin"] = { fg = colors.primary, bold = true },
		--
		-- ["punctuation"] = { fg = colors.gray_4 },
		-- ["operator"] = { fg = colors.gray_4 },
		-- ["punctuation.bracket"] = { fg = colors.gray_4 },
		-- ["punctuation.delimiter"] = { fg = colors.gray_4 },
		-- ["punctuation.list_marker"] = { fg = colors.gray_4 },
		-- ["punctuation.special"] = { fg = colors.gray_4 },
		--
		["comment"] = { fg = colors.gray_2 },
		--
		-- ["comment.doc"] = { fg = colors.gray_3 },
		--
		-- ["function"] = { fg = colors.text },
		-- ["property"] = { fg = colors.text },
		--
		-- ["attribute"] = { fg = colors.orange },
		-- ["function.method"] = { fg = colors.gold },

		["number"] = { fg = colors.red },

		["string"] = { fg = colors.acidGreen },
		--
		-- ["string.regex"] = { fg = colors.green },
		-- ["string.special"] = { fg = colors.green },
		-- ["string.special.symbol"] = { fg = colors.green },
		-- ["text.literal"] = { fg = colors.green },
		--
		-- ["variable.special"] = { fg = colors.darkGray },
		--
		["@comment"] = { link = "comment" },

		IblIndent = { fg = colors.gray_1 },
		IblWhitespace = { link = "IblIndent" },
		IblScope = { link = "IblIndent" },
		["@ibl"] = { link = "IblIndent" },
		["@ibl.indent.char.1"] = { link = "IblIndent" },
		["@ibl.whitespace.char.1"] = { link = "IblIndent" },
		["@ibl.scope.char.1"] = { link = "IblIndent" },
		["@ibl.scope.underline.1"] = { link = "IblIndent" },

		-------- Custom highlights
		RenderMarkdownCode = { bg = colors.markdown_code },
		RenderMarkdownCodeInfo = { fg = colors.gray_4, bg = colors.markdown_code },
		RenderMarkdownCodeBorder = { link = "RenderMarkdownCode" },
		RenderMarkdownCodeFallback = { fg = colors.gray_4, bg = colors.markdown_code },
		RenderMarkdownCodeInline = { fg = colors.text, bg = colors.markdown_code_inline },

		IsThatCenteredLualineNeotestPasing = { fg = colors.white, bg = "#03ff1f" },
		IsThatCenteredLualineNeotestFailing = { fg = colors.white, bg = "#ff0000" },
		IsThatCenteredLualineNeotestPending = { fg = colors.white, bg = colors.gray_3 },

		-- NeogitDiffDeletions = { fg = colors.text, bg = colors.diff_red },
		-- NeogitDiffDeleteHighlight = { link = "NeogitDiffDeletions" },
		-- NeogitDiffDelete = { link = "NeogitDiffDeletions" },
		--
		-- NeogitDiffAdditions = { fg = colors.text, bg = colors.diff_green },
		-- NeogitDiffAddHighlight = { link = "NeogitDiffAdditions" },
		-- NeogitDiffAdd = { link = "NeogitDiffAdditions" },
		--
		-- NeogitDiffAddCursor = {},
		-- NeogitDiffDeleteCursor = {},

		-- @markup.strong xxx cterm=bold gui=bold
		-- @markup.italic xxx cterm=italic gui=italic
		-- @markup.strikethrough xxx cterm=strikethrough gui=strikethrough
		-- Todo           xxx cterm=bold gui=bold guifg=NvimDarkGrey2
		-- Added          xxx ctermfg=2 guifg=NvimDarkGreen
		-- Removed        xxx ctermfg=1 guifg=NvimDarkRed
		-- Changed        xxx ctermfg=6 guifg=NvimDarkCyan
		-- @markup.underline xxx cterm=underline gui=underline

		-- @variable.builtin xxx links to Special
		-- @variable.parameter.builtin xxx links to Special
		-- @constant      xxx links to Constant
		-- @constant.builtin xxx links to Special
		-- @module        xxx links to Structure
		-- @module.builtin xxx links to Special
		-- @label         xxx links to Label
		-- @string        xxx links to String
		-- String         xxx guifg=#51e2b6
		-- @string.regexp xxx links to @string.special
		-- @string.special xxx links to SpecialChar
		-- @string.escape xxx links to @string.special
		-- @string.special.url xxx links to Underlined
		-- @character     xxx links to Character
		-- @character.special xxx links to SpecialChar
		-- @boolean       xxx links to Boolean
		-- @number        xxx links to Number
		-- @number.float  xxx links to Float
		-- @type          xxx links to Type
		-- @type.builtin  xxx links to Special
		-- @attribute     xxx links to Macro
		-- @attribute.builtin xxx links to Special
		-- @property      xxx links to Identifier
		-- Identifier     xxx links to Normal
		-- @function      xxx links to Function
		-- Function       xxx links to Normal
		-- @function.builtin xxx links to Special
		-- @constructor   xxx links to Special
		-- @operator      xxx links to Operator
		-- @keyword       xxx links to Keyword
		-- @punctuation   xxx links to Delimiter
		-- @punctuation.special xxx links to Special
		-- @comment       xxx links to Comment
		-- @comment.error xxx links to DiagnosticError
		-- @comment.warning xxx links to DiagnosticWarn
		-- @comment.note  xxx links to DiagnosticInfo
		-- @comment.todo  xxx links to Todo
		-- @markup        xxx links to Special
		-- @markup.heading xxx links to Title
		-- @markup.link   xxx links to Underlined
		-- @diff          xxx cleared
		-- @diff.plus     xxx links to Added
		-- @diff.minus    xxx links to Removed
		-- @diff.delta    xxx links to Changed
		-- @tag           xxx links to Tag
		-- @tag.builtin   xxx links to Speciale base highlight group. Other Diagnostic highlights link to this by default (except Underline)

		DiagnosticError = { fg = colors.red }, -- Used as th@variable      xxx guifg=NvimDarkGrey2
		DiagnosticWarn = { fg = colors.orange }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
		DiagnosticInfo = { fg = colors.blue }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
		DiagnosticHint = { fg = colors.primary }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
		-- DiagnosticOk = { fg = colors.green }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
		DiagnosticUnderlineError = { undercurl = true, special = colors.red },
		DiagnosticUnderlineWarn = { fg = colors.orange }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
		DiagnosticUnderlineInfo = { fg = colors.blue }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
		DiagnosticUnderlineHint = { fg = colors.gray_3 }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)

		DiagnosticSignError = { bold = true, fg = colors.red },
		DiagnosticSignWarn = { bold = true, fg = colors.orange }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
		DiagnosticSignInfo = { bold = true, fg = colors.blue }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
		DiagnosticSignHint = { bold = true, fg = colors.gray_3 }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)

		DiagnosticLineNumberError = { bold = true, fg = colors.red },
		DiagnosticLineNumberWarn = { fg = colors.orange }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
		DiagnosticLineNumberInfo = { fg = colors.blue }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
		DiagnosticLineNumberHint = { fg = colors.gray_3 }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
		-- BeaconDiagnosticOk = { fg = colors.green }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
		-- ColorColumn    { }, -- Columns set with 'colorcolumn'
		-- Conceal        { }, -- Placeholder characters substituted for concealed text (see 'conceallevel')
		-- Cursor         { }, -- Character under the cursor
		-- CurSearch      { }, -- Highlighting a search pattern under the cursor (see 'hlsearch')
		-- lCursor        { }, -- Character under the cursor when |language-mapping| is used (see 'guicursor')
		-- CursorIM       { }, -- Like Cursor, but used when in IME mode |CursorIM|
		-- CursorColumn   { }, -- Screen-column at the cursor, when 'cursorcolumn' is set.
		-- CursorLine     { bg = colors.gray_0  }, -- Screen-line at the cursor, when 'cursorline' is set. Low-priority if foreground (ctermfg OR guifg) is not set.
		-- Directory      { }, -- Directory names (and other special names in listings)
		--    Current custom highlight colors:
		--
		-- - DiffviewOldLine: light red / pale pink (#f8e1e1)
		-- - DiffviewOldText: stronger light red / muted pink (#efc6c6)
		-- - DiffviewNewLine: light green / pale mint green (#e1f8e1)
		-- - DiffviewNewText: stronger light green / muted mint green (#c5efc5)
		-- - DiffviewMissingLine: light gray (#f1f1f1)
		--
		-- Mapped built-in diff groups in Diffview:
		--
		-- - DiffAdd: uses DiffviewOldLine on the old side, DiffviewNewLine on the new side
		-- - DiffDelete: uses DiffviewMissingLine
		-- - DiffChange: uses DiffviewOldLine on the old side, DiffviewNewLine on the new side
		-- - DiffText: uses DiffviewOldText on the old side, DiffviewNewText on the new side
		DiffviewFilePanelFileName = { fg = colors.gray_4 },
		DiffviewFilePanelSelected = { bold = true },

		DiffviewFilePanelTitle = { fg = colors.text },
		DiffviewFilePanelPath = { fg = colors.text },
		DiffviewFilePanelCounter = { fg = colors.gray_4 },
		DiffviewSecondary = { fg = colors.gray_4 },
		DiffviewOldLine = { bg = colors.diff_red },
		DiffviewOldText = { fg = colors.text, bg = colors.diff_red_text },
		DiffviewNewLine = { bg = colors.diff_green },
		DiffviewNewText = { fg = colors.text, bg = colors.diff_green_text },
		DiffviewMissingLine = { bg = colors.diff_missing },
		DiffAdd = { bg = colors.diff_green }, -- Diff mode: Added line |diff.txt|
		DiffChange = {}, -- Diff mode: Changed line |diff.txt|
		DiffDelete = { bg = colors.diff_red }, -- Diff mode: Deleted line |diff.txt|
		-- DiffText       = { bg = "#afd7d7" }, -- Diff mode: Changed text within a changed line |diff.txt|
		-- EndOfBuffer    { }, -- Filler lines (~) after the end of the buffer. By default, this is highlighted like |hl-NonText|.
		-- TermCursor     { }, -- Cursor in a focused terminal
		-- TermCursorNC   { }, -- Cursor in an unfocused terminal
		-- ErrorMsg       { }, -- Error messages on the command line
		Folded = { link = "Normal" }, -- Line used for closed folds
		-- FoldColumn     { }, -- 'foldcolumn'
		-- SignColumn     { }, -- Column where |signs| are displayed
		-- IncSearch      { }, -- 'incsearch' highlighting also used for the text replaced with ":s///c"
		-- Substitute     { }, -- |:substitute| replacement text highlighting
		-- LineNr         { }, -- Line number for ":number" and ":#" commands, and when 'number' or 'relativenumber' option is set.
		-- LineNrAbove    { }, -- Line number for when the 'relativenumber' option is set, above the cursor line
		-- LineNrBelow    { }, -- Line number for when the 'relativenumber' option is set, below the cursor line
		-- CursorLineNr   { }, -- Like LineNr when 'cursorline' or 'relativenumber' is set for the cursor line.
		-- CursorLineFold { }, -- Like FoldColumn when 'cursorline' is set for the cursor line
		-- CursorLineSign { }, -- Like SignColumn when 'cursorline' is set for the cursor line
		-- MatchParen     { }, -- Character under the cursor or just before it, if it is a paired bracket, and its match. |pi_paren.txt|
		-- ModeMsg        { }, -- 'showmode' message (e.g., "-- INSERT -- ")
		-- MsgArea        { }, -- Area for messages and cmdline
		-- MsgSeparator   { }, -- Separator for scrolled messages, `msgsep` flag of 'display'
		-- MoreMsg        { }, -- |more-prompt|
		-- NonText        { }, -- '@' at the end of the window, characters from 'showbreak' and other characters that do not really exist in the text (e.g., ">" displayed when a double-wide character doesn't fit at the end of the line). See also |hl-EndOfBuffer|.

		-- FloatTitle     { }, -- Title of floating windows.
		-- NormalNC       { }, -- normal text in non-current windows
		-- Pmenu          { }, -- Popup menu: Normal item.
		-- PmenuSel       { }, -- Popup menu: Selected item.
		-- PmenuKind      { }, -- Popup menu: Normal item "kind"
		-- PmenuKindSel   { }, -- Popup menu: Selected item "kind"
		-- PmenuExtra     { }, -- Popup menu: Normal item "extra text"
		-- PmenuExtraSel  { }, -- Popup menu: Selected item "extra text"
		-- PmenuSbar      { }, -- Popup menu: Scrollbar.
		-- PmenuThumb     { }, -- Popup menu: Thumb of the scrollbar.
		-- Question       { }, -- |hit-enter| prompt and yes/no questions
		-- QuickFixLine   { }, -- Current |quickfix| item in the quickfix window. Combined with |hl-CursorLine| when the cursor is there.
		-- Search         { }, -- Last search pattern highlighting (see 'hlsearch'). Also used for similar items that need to stand out.
		-- SpecialKey     { }, -- Unprintable characters: text displayed differently from what it really is. But not 'listchars' whitespace. |hl-Whitespace|
		-- SpellBad       { }, -- Word that is not recognized by the spellchecker. |spell| Combined with the highlighting used otherwise.
		-- SpellCap       { }, -- Word that should start with a capital. |spell| Combined with the highlighting used otherwise.
		-- SpellLocal     { }, -- Word that is recognized by the spellchecker as one that is used in another region. |spell| Combined with the highlighting used otherwise.
		-- SpellRare      { }, -- Word that is recognized by the spellchecker as one that is hardly ever used. |spell| Combined with the highlighting used otherwise.
		-- StatusLine     { }, -- Status line of current window
		-- StatusLineNC   { }, -- Status lines of not-current windows. Note: If this is equal to "StatusLine" Vim will use "^^^" in the status line of the current window.
		-- TabLine        { }, -- Tab pages line, not active tab page label
		-- TabLineFill    { }, -- Tab pages line, where there are no labels
		-- TabLineSel     { }, -- Tab pages line, active tab page label
		-- Title          { }, -- Titles for output from ":set all", ":autocmd" etc.
		-- Visual         { }, -- Visual mode selection
		-- VisualNOS      { }, -- Visual mode selection when vim is "Not Owning the Selection".
		-- WarningMsg     { }, -- Warning messages
		-- Whitespace     { }, -- "nbsp", "space", "tab" and "trail" in 'listchars'
		-- WildMenu       { }, -- Current match in 'wildmenu' completion
		-- WinBar         { }, -- Window bar of current window
		-- WinBarNC       { }, -- Window bar of not-current windows

		-- Common vim syntax groups used for all kinds of code and markup.
		-- Commented-out groups should chain up to their preferred (*) group
		-- by default.
		--
		-- See :h group-name
		--
		-- Uncomment and edit if you want more specific syntax highlighting.

		-- Comment        { }, -- Any comment

		-- Constant       { }, -- (*) Any constant
		-- String         { }, --   A string constant: "this is a string"
		-- Character      { }, --   A character constant: 'c', '\n'
		-- Number         { }, --   A number constant: 234, 0xff
		-- Boolean        { }, --   A boolean constant: TRUE, false
		-- Float          { }, --   A floating point constant: 2.3e10

		-- Identifier     { }, -- (*) Any variable name
		-- Function       { }, --   Function name (also: methods for classes)

		-- Statement      { }, -- (*) Any statement
		-- Conditional    { }, --   if, then, else, endif, switch, etc.
		-- Repeat         { }, --   for, do, while, etc.
		-- Label          { }, --   case, default, etc.
		-- Operator       { }, --   "sizeof", "+", "*", etc.
		-- Keyword        {  fg = colors.primary, bold = true }, --   any other keyword
		-- Exception      { }, --   try, catch, throw

		-- PreProc        { }, -- (*) Generic Preprocessor
		-- Include        { }, --   Preprocessor #include
		-- Define         { }, --   Preprocessor #define
		-- Macro          { }, --   Same as Define
		-- PreCondit      { }, --   Preprocessor #if, #else, #endif, etc.

		-- Type           { }, -- (*) int, long, char, etc.
		-- StorageClass   { }, --   static, register, volatile, etc.
		-- Structure      { }, --   struct, union, enum, etc.
		-- Typedef        { }, --   A typedef

		-- Special        { }, -- (*) Any special symbol
		-- SpecialChar    { }, --   Special character in a constant
		-- Tag            { }, --   You can use CTRL-] on this
		-- Delimiter      { }, --   Character that needs attention
		-- SpecialComment { }, --   Special things inside a comment (e.g. '\n')
		-- Debug          { }, --   Debugging statements

		-- Underlined     { gui = "underline" }, -- Text that stands out, HTML links
		-- Ignore         { }, -- Left blank, hidden |hl-Ignore| (NOTE: May be invisible here in template)
		-- Error = { bg = colors.red }, -- Any erroneous construct
		-- Todo           { }, -- Anything that needs extra attention mostly the keywords TODO FIXME and XXX

		-- These groups are for the native LSP client and diagnostic system. Some
		-- other LSP clients may use these groups, or use their own. Consult your
		-- LSP client's documentation.

		-- See :h lsp-highlight, some groups may not be listed, submit a PR fix to lush-template!
		--
		-- LspReferenceText            { } , -- Used for highlighting "text" references
		-- LspReferenceRead            { } , -- Used for highlighting "read" references
		-- LspReferenceWrite           { } , -- Used for highlighting "write" references
		-- LspCodeLens                 { } , -- Used to color the virtual text of the codelens. See |nvim_buf_set_extmark()|.
		-- LspCodeLensSeparator        { } , -- Used to color the seperator between two or more code lens.
		-- LspSignatureActiveParameter { } , -- Used to highlight the active parameter in the signature help. See |vim.lsp.handlers.signature_help()|.

		-- See :h diagnostic-highlights, some groups may not be listed, submit a PR fix to lush-template!
		--
		-- DiagnosticVirtualTextError { } , -- Used for "Error" diagnostic virtual text.
		-- DiagnosticVirtualTextWarn  { } , -- Used for "Warn" diagnostic virtual text.
		-- DiagnosticVirtualTextInfo  { } , -- Used for "Info" diagnostic virtual text.
		-- DiagnosticVirtualTextHint  { } , -- Used for "Hint" diagnostic virtual text.
		-- DiagnosticVirtualTextOk    { } , -- Used for "Ok" diagnostic virtual text.
		-- DiagnosticUnderlineError   { } , -- Used to underline "Error" diagnostics.
		-- DiagnosticUnderlineWarn    { } , -- Used to underline "Warn" diagnostics.
		-- DiagnosticUnderlineInfo     = { bg = colors.blue } , -- Used to underline "Info" diagnostics.
		-- DiagnosticUnderlineHint = { bg = colors.orange }, -- Used to underline "Hint" diagnostics.
		-- DiagnosticUnderlineOk      { } , -- Used to underline "Ok" diagnostics.
		-- DiagnosticFloatingError    { } , -- Used to color "Error" diagnostic messages in diagnostics float. See |vim.diagnostic.open_float()|
		-- DiagnosticFloatingWarn     { } , -- Used to color "Warn" diagnostic messages in diagnostics float.
		-- DiagnosticFloatingInfo     { } , -- Used to color "Info" diagnostic messages in diagnostics float.
		-- DiagnosticFloatingHint     { } , -- Used to color "Hint" diagnostic messages in diagnostics float.
		-- DiagnosticFloatingOk       { } , -- Used to color "Ok" diagnostic messages in diagnostics float.
		-- DiagnosticSignError =       { fg= colors.red } , -- Used for "Error" signs in sign column.
		-- DiagnosticSignWarn  =       {  fg= colors.orange} , -- Used for "Warn" signs in sign column.
		-- DiagnosticSignInfo  =       { fg = colors.blue}  , -- Used for "Info" signs in sign column.
		-- DiagnosticSignHint  =       { fg = colors.secondary} ,  -- Used for "Hint" signs in sign column.
		-- DiagnosticSignOk           { fg = colors.acidGreen} , -- Used for "Ok" signs in sign column.

		-- Tree-Sitter syntax groups.
		--
		-- See :h treesitter-highlight-groups, some groups may not be listed,
		-- submit a PR fix to lush-template!
		--
		-- Tree-Sitter groups are defined with an "@" symbol, which must be
		-- specially handled to be valid lua code, we do this via the special
		-- sym function. The following are all valid ways to call the sym function,
		-- for more details see https://www.lua.org/pil/5.html
		--
		-- sym("@text.literal")
		-- sym('@text.literal')
		-- sym"@text.literal"
		-- sym'@text.literal'
		--
		-- For more information see https://github.com/rktjmp/lush.nvim/issues/109

		-- sym"@text.literal"      { }, -- Comment
		-- sym"@text.reference"    { }, -- Identifier
		-- sym"@text.title"        { }, -- Title
		-- sym"@text.uri"          { }, -- Underlined
		-- sym"@text.underline"    { }, -- Underlined
		-- sym"@text.todo"         { }, -- Todo
		-- sym"@comment"           { }, -- Comment
		-- sym"@punctuation"       { }, -- Delimiter
		-- sym"@constant"          { }, -- Constant
		-- sym"@constant.builtin"  { }, -- Special
		-- sym"@constant.macro"    { }, -- Define
		-- sym"@define"            { }, -- Define
		-- sym"@macro"             { }, -- Macro
		-- sym"@string"            { }, -- String
		-- sym"@string.escape"     { }, -- SpecialChar
		-- sym"@string.special"    { }, -- SpecialChar
		-- sym"@character"         { }, -- Character
		-- sym"@character.special" { }, -- SpecialChar
		-- sym"@number"            { }, -- Number
		-- sym"@boolean"           { }, -- Boolean
		-- sym"@float"             { }, -- Float
		-- sym"@function"          { }, -- Function
		-- sym"@function.builtin"  { }, -- Special
		-- sym"@function.macro"    { }, -- Macro
		-- sym"@parameter"         { }, -- Identifier
		-- sym"@method"            { }, -- Function
		-- sym"@field"             { }, -- Identifier
		-- sym"@property"          { }, -- Identifier
		-- sym"@constructor"       { }, -- Special
		-- sym"@conditional"       { }, -- Conditional
		-- sym"@repeat"            { }, -- Repeat
		-- sym"@label"             { }, -- Label
		-- sym"@operator"          { }, -- Operator
		-- sym"@keyword"           { }, -- Keyword
		-- sym"@exception"         { }, -- Exception
		-- sym"@variable"          { }, -- Identifier
		-- sym"@type"              { }, -- Type
		-- sym"@type.definition"   { }, -- Typedef
		-- sym"@storageclass"      { }, -- StorageClass
		-- sym"@structure"         { }, -- Structure
		-- sym"@namespace"         { }, -- Identifier
		-- sym"@include"           { }, -- Include
		-- sym"@preproc"           { }, -- PreProc
		-- sym"@debug"             { }, -- Debug
		-- sym"@tag"               { }, -- Tag
		-- TREESITTER COLORS
		-- ['constant'] = { fg = colors.blue },
		-- ['constructor'] = { fg = colors.blue },
		-- ['embedded'] = { fg = colors.blue },
		-- ['emphasis'] = { fg = colors.blue },
		-- ['emphasis.strong'] = { fg = colors.blue },
		-- ['enum'] = { fg = colors.blue },
		-- ['function.special.definition'] = { fg = colors.blue },
		-- ['hint'] = { fg = colors.blue },
		-- ['label'] = { fg = colors.blue },
		-- ['link_text'] = { fg = colors.blue },
		-- ['link_uri'] = { fg = colors.blue },
		-- ['predictive'] = { fg = colors.blue },
		-- ['preproc'] = { fg = colors.blue },
		-- ['primary'] = { fg = colors.blue },
		-- ['tag'] = { fg = colors.blue },
		-- ['string.escape'] = { fg = colors.blue },
		-- ['title'] = { fg = colors.blue },
		-- ['variant'] = { fg = colors.blue },
	}

	for group, opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, group, opts)
	end
end

return M
