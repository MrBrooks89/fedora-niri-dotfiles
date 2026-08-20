-- ~/.config/nvim/lua/plugins/dap.lua

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = { "rcarriga/nvim-dap-ui", "nvim-neotest/nvim-nio" },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()

      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

      vim.keymap.set("n", "<F5>", function() dap.continue() end, { desc = "DAP Continue" })
      vim.keymap.set("n", "<leader>db", function() dap.toggle_breakpoint() end, { desc = "DAP Breakpoint" })
    end,
  },
}
