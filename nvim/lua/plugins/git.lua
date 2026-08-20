-- ~/.config/nvim/lua/plugins/git.lua

return {
  { "lewis6991/gitsigns.nvim", opts = {} },
  {
    "TimUntersberger/neogit",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { kind = "floating" },
  },
  { "sindrets/diffview.nvim" },
}
