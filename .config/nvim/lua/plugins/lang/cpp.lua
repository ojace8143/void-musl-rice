-- C++: same clangd/clang-format stack as C, plus the C++ parser.
local clang = require("config.lang")

return {
        {
                "nvim-treesitter/nvim-treesitter",
                opts = { ensure_installed = { "cpp" } },
        },
        {
                "stevearc/conform.nvim",
                opts = {
                        formatters_by_ft = {
                                cpp = { "clang-format" },
                        },
                        formatters = {
                                ["clang-format"] = {
                                        prepend_args = clang.clang_format_args,
                                },
                        },
                },
        },
}
