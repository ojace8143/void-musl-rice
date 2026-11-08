-- C: clangd (also serves C++), clang-format, treesitter.
local clang = require("config.lang")

-- clangd's `textDocument/switchSourceHeader` returns the partner file's URI.
local function switch_source_header()
        vim.lsp.buf_request(0, "textDocument/switchSourceHeader", { uri = vim.uri_from_bufnr(0) }, function(_, result)
                if result then
                        vim.cmd.edit(vim.uri_to_fname(result))
                end
        end)
end

return {
        {
                "nvim-treesitter/nvim-treesitter",
                opts = { ensure_installed = { "c" } },
        },
        {
                "mason-org/mason.nvim",
                opts = { ensure_installed = { "clangd", "clang-format" } },
        },
        {
                "neovim/nvim-lspconfig",
                opts = {
                        servers = {
                                clangd = {
                                        keys = {
                                                {
                                                        "<leader>ch",
                                                        switch_source_header,
                                                        desc = "Switch Source/Header (C/C++)",
                                                },
                                        },
                                        cmd = {
                                                "clangd",
                                                "--background-index",
                                                "--clang-tidy",
                                                "--header-insertion=iwyu",
                                                "--completion-style=detailed",
                                                "--function-arg-placeholders",
                                                "--fallback-style=LLVM",
                                        },
                                        init_options = {
                                                usePlaceholders = true,
                                                completeUnimported = true,
                                                clangdFileStatus = true,
                                        },
                                        capabilities = {
                                                offsetEncoding = { "utf-16" },
                                        },
                                },
                        },
                },
        },
        {
                "stevearc/conform.nvim",
                opts = {
                        formatters_by_ft = {
                                c = { "clang-format" },
                        },
                        formatters = {
                                ["clang-format"] = {
                                        prepend_args = clang.clang_format_args,
                                },
                        },
                },
        },
}
