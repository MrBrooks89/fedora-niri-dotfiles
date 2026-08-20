-- ~/.config/nvim/init.lua

-- Suppress specific deprecation warnings for bleeding-edge Neovim 0.11
local notify = vim.notify
vim.notify = function(msg, ...)
  if msg:match("lspconfig") or msg:match("create_default_mappings") or msg:match("leap") then
    return
  end
  notify(msg, ...)
end

require("config.options")
require("config.lazy")
require("config.keymaps")
