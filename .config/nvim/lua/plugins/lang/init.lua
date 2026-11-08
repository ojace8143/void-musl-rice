-- Lazy imports `lua/plugins/*.lua` and subdirectories that contain an
-- `init.lua`, so this file pulls in the per-language specs next to it.
return {
        { import = "plugins.lang.c" },
        { import = "plugins.lang.cpp" },
        { import = "plugins.lang.shell" },
        { import = "plugins.lang.asm" },
        { import = "plugins.lang.zig" },
}
