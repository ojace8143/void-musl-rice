-- The snacks dashboard footer ("⚡ Neovim loaded 3/32 plugins in 27ms") is
-- rendered when the dashboard opens on `UIEnter`. lazy.nvim loads the rest of
-- the plugins on the `VeryLazy` event, which is *scheduled* right after
-- `UIEnter`, so the footer always snapshots the stats too early and permanently
-- shows the 3 startup plugins (lazy.nvim, LazyVim, snacks.nvim) instead of the
-- real count.
--
-- Re-render the dashboard once `VeryLazy` has fired, with the stats cache
-- invalidated so the footer shows the true number of loaded plugins.
return {
  {
    "folke/snacks.nvim",
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          -- wait until every `VeryLazy` handler has finished loading plugins
          vim.schedule(function()
            local ok, dashboard = pcall(require, "snacks.dashboard")
            if not ok or not dashboard.lazy_stats then
              return -- lazy.nvim not installed, or the dashboard never rendered
            end
            dashboard.lazy_stats = nil -- force fresh `require("lazy.stats").stats()`
            pcall(function()
              Snacks.dashboard.update()
            end)
          end)
        end,
      })
    end,
  },
}
