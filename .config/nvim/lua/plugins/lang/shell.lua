-- Shell: bash-language-server, shellcheck, shfmt (8-space, case-indented).
return {
        {
                "nvim-treesitter/nvim-treesitter",
                opts = { ensure_installed = { "bash" } },
        },
        {
                "mason-org/mason.nvim",
                opts = { ensure_installed = { "bash-language-server", "shellcheck" } },
        },
        {
                "neovim/nvim-lspconfig",
                opts = {
                        servers = {
                                bashls = {
                                        settings = {
                                                bashIde = {
                                                        -- Keep shellcheck diagnostics owned by nvim-lint below.
                                                        shellcheckDiagnostics = { enable = false },
                                                },
                                        },
                                },
                        },
                },
        },
        {
                "stevearc/conform.nvim",
                opts = {
                        formatters_by_ft = {
                                sh = { "shfmt" },
                                bash = { "shfmt" },
                        },
                        formatters = {
                                shfmt = {
                                        -- The builtin puts `-i <shiftwidth>` after `-filename`, which shfmt's
                                        -- flag parser ignores, so build the whole argv ourselves.
                                        args = function(_, ctx)
                                                return {
                                                        "-i",
                                                        tostring(ctx.shiftwidth or 8),
                                                        "-ci",
                                                        "-sr",
                                                        "-filename",
                                                        "$FILENAME",
                                                }
                                        end,
                                },
                        },
                },
        },
        {
                "mfussenegger/nvim-lint",
                opts = {
                        linters_by_ft = {
                                sh = { "shellcheck" },
                                bash = { "shellcheck" },
                        },
                },
        },
}
