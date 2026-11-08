-- Shared helpers for the per-language plugin specs in `lua/plugins/lang/`.
local M = {}

--- conform.nvim `prepend_args` for clang-format.
--- Projects that ship their own `.clang-format` keep full control; otherwise we
--- fall back to the void 8-space style so format-on-save matches the editor.
function M.clang_format_args(_, ctx)
        local found = vim.fs.find({ ".clang-format", "_clang-format" }, { path = ctx.dirname, upward = true })[1]
        if found then
                return {}
        end
        return { "--style={BasedOnStyle: LLVM, IndentWidth: 8, TabWidth: 8, UseTab: Never, ColumnLimit: 120}" }
end

return M
