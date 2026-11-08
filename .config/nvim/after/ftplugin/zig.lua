-- Zig: 8-space indentation (see ~/.colors and stylua.toml).
-- The stock Neovim ftplugin forces shiftwidth=4; this file loads afterwards and wins.
vim.opt_local.expandtab = true
vim.opt_local.tabstop = 8
vim.opt_local.softtabstop = 8
vim.opt_local.shiftwidth = 8

-- `zig fmt` (and zls formatting) hardcodes 4-space indents, which would silently
-- undo the 8-space rule on every save. Keep autoformat off for Zig buffers.
vim.b.autoformat = false
