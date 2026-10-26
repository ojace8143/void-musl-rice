-- void.lua — colorscheme matching the Void Linux "void-dark" rice
-- palette mirrors ~/.config/foot/foot.ini

vim.o.background = "dark"
vim.o.termguicolors = true

if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.cmd("highlight clear")

vim.g.colors_name = "void"

local function hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

local bg0 = "#1b1f23"
local bg1 = "#23282d"
local bg2 = "#2a3036"
local fg = "#c9d1cf"
local muted = "#505a63"
local green = "#478061"
local green_br = "#6fae86"
local red = "#c46a6a"
local red_br = "#d98a8a"
local yellow = "#d8b26b"
local yellow_br = "#e6c88a"
local blue = "#6f9fd1"
local blue_br = "#8fb8e0"
local magenta = "#b184c9"
local magenta_br = "#c79ed6"
local cyan = "#68b0a8"
local cyan_br = "#84c6bf"
local white = "#f0f4f2"

-- editor UI
hl("Normal", { fg = fg, bg = bg0 })
hl("NormalNC", { fg = fg, bg = bg0 })
hl("NormalFloat", { fg = fg, bg = bg1 })
hl("FloatBorder", { fg = green, bg = bg1 })
hl("FloatTitle", { fg = green, bg = bg1, bold = true })
hl("FloatFooter", { fg = muted, bg = bg1 })
hl("Cursor", { fg = bg0, bg = fg })
hl("lCursor", { fg = bg0, bg = fg })
hl("CursorLine", { bg = bg1 })
hl("CursorColumn", { bg = bg1 })
hl("ColorColumn", { bg = bg1 })
hl("LineNr", { fg = muted })
hl("CursorLineNr", { fg = green, bold = true })
hl("CursorLineFold", { fg = bg2 })
hl("SignColumn", { bg = bg0 })
hl("FoldColumn", { fg = muted, bg = bg0 })
hl("Folded", { fg = muted, bg = bg1 })
hl("WinSeparator", { fg = bg2 })
hl("VertSplit", { link = "WinSeparator" })
hl("StatusLine", { fg = fg, bg = bg1 })
hl("StatusLineNC", { fg = muted, bg = bg1 })
hl("TabLine", { fg = muted, bg = bg1 })
hl("TabLineSel", { fg = bg0, bg = green, bold = true })
hl("TabLineFill", { bg = bg1 })
hl("Pmenu", { fg = fg, bg = bg1 })
hl("PmenuSel", { fg = bg0, bg = green, bold = true })
hl("PmenuKind", { fg = blue, bg = bg1 })
hl("PmenuKindSel", { fg = bg0, bg = green })
hl("PmenuExtra", { fg = muted, bg = bg1 })
hl("PmenuSbar", { bg = bg1 })
hl("PmenuThumb", { bg = bg2 })
hl("Visual", { bg = "#33463d" })
hl("VisualNOS", { bg = "#33463d" })
hl("Search", { fg = bg0, bg = green })
hl("IncSearch", { fg = bg0, bg = yellow })
hl("CurSearch", { fg = bg0, bg = yellow })
hl("MatchParen", { fg = yellow, bold = true })
hl("NonText", { fg = bg2 })
hl("SpecialKey", { fg = muted })
hl("Whitespace", { fg = bg2 })
hl("Title", { fg = green, bold = true })
hl("Directory", { fg = green })
hl("ErrorMsg", { fg = red_br })
hl("WarningMsg", { fg = yellow })
hl("MoreMsg", { fg = green })
hl("Question", { fg = green })
hl("ModeMsg", { fg = fg, bold = true })
hl("Error", { fg = red_br })
hl("Todo", { fg = bg0, bg = yellow, bold = true })
hl("QuickFixLine", { bg = bg1 })
hl("qfFileName", { fg = green })
hl("qfLineNr", { fg = muted })
hl("Conceal", { fg = muted })
hl("Added", { fg = green_br })
hl("Removed", { fg = red_br })
hl("Changed", { fg = blue_br })

-- diagnostics
hl("DiagnosticError", { fg = red_br })
hl("DiagnosticWarn", { fg = yellow })
hl("DiagnosticInfo", { fg = blue })
hl("DiagnosticHint", { fg = cyan_br })
hl("DiagnosticOk", { fg = green_br })
hl("DiagnosticVirtualTextError", { fg = red_br, bg = bg1 })
hl("DiagnosticVirtualTextWarn", { fg = yellow, bg = bg1 })
hl("DiagnosticVirtualTextInfo", { fg = blue, bg = bg1 })
hl("DiagnosticVirtualTextHint", { fg = cyan_br, bg = bg1 })
hl("DiagnosticUnderlineError", { sp = red_br, undercurl = true })
hl("DiagnosticUnderlineWarn", { sp = yellow, undercurl = true })
hl("DiagnosticUnderlineInfo", { sp = blue, undercurl = true })
hl("DiagnosticUnderlineHint", { sp = cyan_br, undercurl = true })
hl("DiagnosticUnnecessary", { fg = muted })

-- lsp
hl("LspReferenceText", { bg = bg1 })
hl("LspReferenceRead", { bg = bg1 })
hl("LspReferenceWrite", { bg = bg1 })
hl("LspSignatureActiveParameter", { fg = yellow, bold = true })
hl("LspCodeLens", { fg = muted })

-- diff
hl("DiffAdd", { fg = green_br, bg = "#1e2b24" })
hl("DiffChange", { fg = blue_br, bg = "#1e2530" })
hl("DiffDelete", { fg = red, bg = "#2b1e1e" })
hl("DiffText", { fg = bg0, bg = blue })

-- classic syntax
hl("Comment", { fg = muted, italic = true })
hl("Constant", { fg = yellow })
hl("String", { fg = green_br })
hl("Character", { fg = green_br })
hl("Number", { fg = yellow })
hl("Boolean", { fg = yellow })
hl("Float", { fg = yellow })
hl("Identifier", { fg = fg })
hl("Function", { fg = blue })
hl("Statement", { fg = magenta })
hl("Conditional", { fg = magenta })
hl("Repeat", { fg = magenta })
hl("Label", { fg = magenta })
hl("Operator", { fg = cyan })
hl("Keyword", { fg = magenta })
hl("Exception", { fg = magenta })
hl("PreProc", { fg = cyan })
hl("Include", { fg = magenta })
hl("Define", { fg = magenta })
hl("Macro", { fg = cyan })
hl("PreCondit", { fg = cyan })
hl("Type", { fg = yellow })
hl("StorageClass", { fg = magenta })
hl("Structure", { fg = yellow })
hl("Typedef", { fg = yellow })
hl("Special", { fg = cyan_br })
hl("SpecialChar", { fg = yellow })
hl("Tag", { fg = green })
hl("Delimiter", { fg = fg })
hl("SpecialComment", { fg = muted, italic = true })
hl("Debug", { fg = red })
hl("Underlined", { underline = true })
hl("Bold", { bold = true })
hl("Italic", { italic = true })

-- treesitter
hl("@variable", { fg = fg })
hl("@variable.builtin", { fg = magenta })
hl("@variable.parameter", { fg = fg })
hl("@variable.member", { fg = blue_br })
hl("@constant", { fg = yellow })
hl("@constant.builtin", { fg = yellow })
hl("@constant.macro", { fg = cyan })
hl("@module", { fg = blue_br })
hl("@label", { fg = magenta })
hl("@string", { fg = green_br })
hl("@string.escape", { fg = yellow })
hl("@string.special", { fg = cyan_br })
hl("@character", { fg = green_br })
hl("@number", { fg = yellow })
hl("@boolean", { fg = yellow })
hl("@float", { fg = yellow })
hl("@function", { fg = blue })
hl("@function.builtin", { fg = blue_br })
hl("@function.call", { fg = blue })
hl("@function.macro", { fg = cyan })
hl("@function.method", { fg = blue })
hl("@constructor", { fg = yellow })
hl("@operator", { fg = cyan })
hl("@keyword", { fg = magenta })
hl("@keyword.function", { fg = magenta })
hl("@keyword.operator", { fg = cyan })
hl("@keyword.return", { fg = magenta })
hl("@keyword.import", { fg = magenta })
hl("@conditional", { fg = magenta })
hl("@repeat", { fg = magenta })
hl("@exception", { fg = magenta })
hl("@type", { fg = yellow })
hl("@type.builtin", { fg = yellow })
hl("@type.definition", { fg = yellow })
hl("@namespace", { fg = blue_br })
hl("@property", { fg = blue_br })
hl("@field", { fg = blue_br })
hl("@parameter", { fg = fg })
hl("@comment", { fg = muted, italic = true })
hl("@punctuation", { fg = fg })
hl("@punctuation.delimiter", { fg = fg })
hl("@punctuation.bracket", { fg = fg })
hl("@punctuation.special", { fg = cyan })
hl("@tag", { fg = green })
hl("@tag.attribute", { fg = blue_br })
hl("@tag.delimiter", { fg = fg })
hl("@markup.heading", { fg = green, bold = true })
hl("@markup.link", { fg = blue_br, underline = true })
hl("@markup.link.label", { fg = blue_br })
hl("@markup.raw", { fg = yellow })
hl("@markup.italic", { italic = true })
hl("@markup.bold", { bold = true })
hl("@markup.list", { fg = cyan })
hl("@diff.plus", { fg = green_br })
hl("@diff.minus", { fg = red_br })
hl("@diff.delta", { fg = blue_br })

-- lsp semantic tokens
hl("@lsp.type.class", { link = "@type" })
hl("@lsp.type.struct", { link = "@type" })
hl("@lsp.type.enum", { link = "@type" })
hl("@lsp.type.enumMember", { link = "@constant" })
hl("@lsp.type.interface", { link = "@type" })
hl("@lsp.type.parameter", { link = "@variable.parameter" })
hl("@lsp.type.property", { link = "@property" })
hl("@lsp.type.function", { link = "@function" })
hl("@lsp.type.method", { link = "@function.method" })
hl("@lsp.type.macro", { link = "@constant.macro" })
hl("@lsp.type.variable", { link = "@variable" })
hl("@lsp.type.namespace", { link = "@namespace" })
hl("@lsp.type.keyword", { link = "@keyword" })
hl("@lsp.type.decorator", { link = "@function" })

-- plugins
hl("CmpItemAbbr", { fg = fg })
hl("CmpItemAbbrDeprecated", { fg = muted, strikethrough = true })
hl("CmpItemAbbrMatch", { fg = green_br, bold = true })
hl("CmpItemAbbrMatchFuzzy", { fg = green_br })
hl("CmpItemKind", { fg = blue })
hl("CmpItemMenu", { fg = muted })
hl("GitSignsAdd", { fg = green_br })
hl("GitSignsChange", { fg = blue_br })
hl("GitSignsDelete", { fg = red_br })
hl("TelescopeNormal", { fg = fg, bg = bg1 })
hl("TelescopeBorder", { fg = green, bg = bg1 })
hl("TelescopePromptNormal", { fg = fg, bg = bg1 })
hl("TelescopePromptBorder", { fg = green, bg = bg1 })
hl("TelescopePromptTitle", { fg = bg0, bg = green })
hl("TelescopeResultsTitle", { fg = green, bg = bg1 })
hl("TelescopePreviewTitle", { fg = bg0, bg = green })
hl("TelescopeSelection", { bg = bg2 })
hl("TelescopeSelectionCaret", { fg = green, bg = bg2 })
hl("TelescopeMatching", { fg = green_br, bold = true })
hl("SnacksPicker", { fg = fg, bg = bg1 })
hl("SnacksPickerBorder", { fg = green, bg = bg1 })
hl("SnacksPickerTitle", { fg = green, bg = bg1, bold = true })
hl("SnacksPickerMatch", { fg = green_br, bold = true })
hl("SnacksNotifierInfo", { fg = blue, bg = bg1 })
hl("SnacksNotifierWarn", { fg = yellow, bg = bg1 })
hl("SnacksNotifierError", { fg = red_br, bg = bg1 })
hl("SnacksNotifierOk", { fg = green_br, bg = bg1 })
hl("SnacksNotifierBorderInfo", { fg = blue, bg = bg1 })
hl("SnacksNotifierBorderWarn", { fg = yellow, bg = bg1 })
hl("SnacksNotifierBorderError", { fg = red_br, bg = bg1 })
hl("SnacksNotifierBorderOk", { fg = green_br, bg = bg1 })

-- terminal palette (match foot)
vim.g.terminal_color_0 = bg0
vim.g.terminal_color_1 = red
vim.g.terminal_color_2 = green
vim.g.terminal_color_3 = yellow
vim.g.terminal_color_4 = blue
vim.g.terminal_color_5 = magenta
vim.g.terminal_color_6 = cyan
vim.g.terminal_color_7 = fg
vim.g.terminal_color_8 = muted
vim.g.terminal_color_9 = red_br
vim.g.terminal_color_10 = green_br
vim.g.terminal_color_11 = yellow_br
vim.g.terminal_color_12 = blue_br
vim.g.terminal_color_13 = magenta_br
vim.g.terminal_color_14 = cyan_br
vim.g.terminal_color_15 = white
