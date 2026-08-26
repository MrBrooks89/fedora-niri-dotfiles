-- ~/.config/nvim/lua/plugins/ui.lua

return {
  -- Theme
  {
    "Mofiqul/dracula.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("dracula").setup({
        transparent_bg = false,
        italic_comment = true,
      })
      vim.cmd([[colorscheme dracula]])
      local generated_theme = vim.fn.stdpath("cache") .. "/noctalia/neovim.lua"
      if vim.fn.filereadable(generated_theme) == 1 then
        dofile(generated_theme)
      end
    end,
  },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { theme = "auto" } },
  },

  -- Bufferline (Tabline)
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = "nvim-tree/nvim-web-devicons",
    opts = {
      options = {
        diagnostics = "nvim_lsp",
        offsets = { { filetype = "neo-tree", text = "File Explorer", padding = 1 } },
      },
    },
  },

  -- File Explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
    opts = {
      window = { width = 30 },
      filesystem = { follow_current_file = { enabled = true } },
    },
  },

  -- Dashboard
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("alpha").setup(require("alpha.themes.startify").config)
    end,
  },

  -- Notifications & UI
  { "rcarriga/nvim-notify", opts = {} },
  {
    "folke/noice.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    opts = { lsp = { override = { ["vim.lsp.util.convert_input_to_markdown_lines"] = true } } },
  },

  -- Which-Key
  { "folke/which-key.nvim", opts = {} },

  -- Visual Polish
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
  { "petertriho/nvim-scrollbar", opts = {} },
  { "j-hui/fidget.nvim", opts = {} },
}
