-- ~/.config/nvim/lua/plugins/editor.lua

return {
  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")
      local parsers = { "nix", "python", "go", "rust", "bash", "lua", "regex", "gitcommit", "gitignore", "git_rebase", "gitattributes" }

      treesitter.setup({})
      treesitter.install(parsers)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "nix", "python", "go", "rust", "bash", "sh", "lua", "gitcommit", "gitignore", "gitrebase", "gitattributes" },
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
        desc = "Enable Treesitter highlighting and indentation",
      })
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
  { "smoka7/hop.nvim", version = "*", opts = {} },
  {
    url = "https://codeberg.org/andyg/leap.nvim",
    config = function()
      vim.keymap.set({ "n", "x", "o" }, "s", "<Plug>(leap-forward)")
      vim.keymap.set({ "n", "x", "o" }, "S", "<Plug>(leap-backward)")
    end,
  },
}
