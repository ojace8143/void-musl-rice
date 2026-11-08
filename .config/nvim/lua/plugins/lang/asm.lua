-- Assembly (GAS/NASM): asm-lsp + treesitter.
-- No formatter on purpose: conform's `asmfmt` targets Go assembly and would
-- mangle GAS/NASM sources.
--
-- The mason build of asm-lsp compiles from source and needs OpenSSL headers
-- that this box does not have, so use the upstream static release instead
-- (mason = false).
local asm_lsp = vim.fn.stdpath("data") .. "/asm-lsp/0.10.1/asm-lsp"

return {
        {
                "nvim-treesitter/nvim-treesitter",
                opts = { ensure_installed = { "asm" } },
        },
        {
                "neovim/nvim-lspconfig",
                opts = {
                        servers = {
                                asm_lsp = {
                                        mason = false,
                                        cmd = { asm_lsp },
                                },
                        },
                },
        },
}
