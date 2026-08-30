-- ~/.config/nvim/lua/plugins/lsp.lua

return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "saghen/blink.cmp",
      "nvimdev/lspsaga.nvim",
      "folke/trouble.nvim",
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = { "pyright", "gopls", "rust_analyzer", "bashls", "lua_ls", "taplo", "yamlls" },
        automatic_enable = false,
      })

      require("lspsaga").setup({
        ui = { border = "rounded" },
      })

      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local servers = { "pyright", "gopls", "rust_analyzer", "bashls", "lua_ls", "taplo", "yamlls" }
      vim.lsp.config("*", { capabilities = capabilities })
      vim.lsp.enable(servers)

      -- LSP Specific Keymaps
      local map = vim.keymap.set
      map("n", "K", "<cmd>Lspsaga hover_doc<CR>", { desc = "LSP Hover" })
      map("n", "gd", "<cmd>Lspsaga goto_definition<CR>", { desc = "Go to Definition" })
      map("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", { desc = "Rename" })
      map("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>", { desc = "Code Action" })
      map("n", "[d", "<cmd>Lspsaga diagnostic_jump_prev<CR>", { desc = "Prev Diagnostic" })
      map("n", "]d", "<cmd>Lspsaga diagnostic_jump_next<CR>", { desc = "Next Diagnostic" })
    end,
  },

  {
    "saghen/blink.cmp",
    version = "v0.*",
    opts = {
      keymap = {
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },
      completion = {
        list = { selection = { preselect = false, auto_insert = false } },
        ghost_text = { enabled = false },
      },
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = "mono",
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
    },
  },

  { "folke/trouble.nvim", opts = {} },
}
