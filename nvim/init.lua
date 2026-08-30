-- ~/.config/nvim/init.lua

-- None of the configured plugins use the optional remote-plugin providers.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0

require("config.options")
require("config.lazy")
require("config.keymaps")
