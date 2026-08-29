return {
  {
    "github/copilot.vim",
    branch = "release",
    event = "InsertEnter",
    cmd = "Copilot",
    init = function()
      -- Keep Tab available for blink.cmp completion-menu navigation.
      vim.g.copilot_no_tab_map = true
    end,
    config = function()
      vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
        expr = true,
        replace_keycodes = false,
        silent = true,
        desc = "Accept Copilot suggestion",
      })
    end,
  },
}
