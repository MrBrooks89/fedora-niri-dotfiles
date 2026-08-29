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

      -- Codex CLI integration
      local Terminal = require('toggleterm.terminal').Terminal
      local codex_terminal = Terminal:new({
        cmd = "codex",
        hidden = true,
        direction = "float",
        float_opts = { border = "double" },
        on_open = function(term)
          vim.cmd("startinsert")
          local input_group = vim.api.nvim_create_augroup("CodexTerminalInput", { clear = true })
          vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
            group = input_group,
            buffer = term.bufnr,
            callback = function()
              if vim.api.nvim_get_current_buf() == term.bufnr then
                vim.cmd("startinsert")
              end
            end,
            desc = "Return the Codex terminal to input mode when focused",
          })
        end,
      })

      function _codex_terminal_toggle()
        codex_terminal:toggle()
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
      map("n", "<leader>tc", "<cmd>lua _codex_terminal_toggle()<CR>", { silent = true, desc = "Codex CLI Terminal" })
      map("n", "<leader>tt", "<cmd>ToggleTerm direction=float<CR>", { silent = true, desc = "Floating Terminal" })
    end,
  },
}
