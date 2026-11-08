-- Zig: zls + treesitter.
-- NOTE: `zig fmt` always emits 4-space indents, so autoformat stays disabled in
-- `after/ftplugin/zig.lua` to preserve the 8-space rule.
--
-- Mason ships zls 0.17, which is built against a newer Zig than this machine's
-- 0.13.0, so zls is pinned to the matching release instead (mason = false).
local zls = vim.fn.stdpath("data") .. "/zls/0.13.0/zls"

return {
        {
                "nvim-treesitter/nvim-treesitter",
                opts = { ensure_installed = { "zig" } },
        },
        {
                "neovim/nvim-lspconfig",
                opts = {
                        servers = {
                                zls = {
                                        mason = false,
                                        cmd = { zls },
                                },
                        },
                },
        },
}
