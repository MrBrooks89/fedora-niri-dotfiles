-- ~/.config/nvim/lua/plugins/terminal.lua

return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = 20,
        open_mapping = [[<c-\>]],
        direction = "float",
        float_opts = { border = "double" },
      })

      -- Gemini CLI Integration (Replicated from nvf)
      local Terminal = require('toggleterm.terminal').Terminal
      local gemini_terminal = Terminal:new({
        cmd = "gemini",
        hidden = true,
        direction = "float",
        float_opts = { border = "double" },
      })

      function _gemini_terminal_toggle()
        gemini_terminal:toggle()
      end

      -- Lazygit Integration
      local lazygit = Terminal:new({
        cmd = "lazygit",
        dir = "git_dir",
        direction = "float",
        float_opts = { border = "double"},
        on_open = function(term)
          vim.cmd("startinsert!")
          vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", {noremap = true, silent = true})
        end,
      })
      function _lazygit_toggle()
        lazygit:toggle()
      end

      local map = vim.keymap.set
      map ("n", "<leader>g", "<cmd>lua_lazygit_toggle()<CR>", {silent = true, desc = "Lazygit"})
      map("n", "<leader>tg", "<cmd>lua _gemini_terminal_toggle()<CR>", { silent = true, desc = "Gemini CLI Terminal" })
      map("n", "<leader>tt", "<cmd>ToggleTerm direction=float<CR>", { silent = true, desc = "Floating Terminal" })
    end,
  },
}
