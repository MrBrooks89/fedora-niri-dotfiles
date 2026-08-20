-- ~/.config/nvim/lua/plugins/editor.lua

return {
  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      -- Use a protected call to handle changing Treesitter API versions
      local status, ts = pcall(require, "nvim-treesitter.configs")
      if status then
        ts.setup({
          ensure_installed = { "nix", "python", "go", "rust", "bash", "lua", "gitcommit", "gitignore", "git_rebase", "gitattributes" },
          highlight = { enable = true },
          indent = { enable = true },
        })
      end
    end,
  },

  -- Telescope
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      defaults = {
        mappings = { i = { ["jj"] = "close" } },
      },
    },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live Grep" },
    },
  },

  -- Editing Utilities
  { "windwp/nvim-autopairs", opts = {} },
  { "numToStr/Comment.nvim", opts = {} },
  { "smoka7/hop.nvim", version = "*", opts = {} },
  { 
    url = "https://codeberg.org/andyg/leap.nvim",
    config = function() 
      local leap = require('leap')
      -- Use the most stable mapping method
      vim.keymap.set({'n', 'x', 'o'}, 's',  '<Plug>(leap-forward)')
      vim.keymap.set({'n', 'x', 'o'}, 'S',  '<Plug>(leap-backward)')
    end,
  },
}
