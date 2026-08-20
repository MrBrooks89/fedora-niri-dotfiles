-- ~/.config/nvim/lua/config/keymaps.lua

local map = vim.keymap.set

-- General
map("i", "jj", "<Esc>", { silent = true })
map("v", "y", '"+y', { noremap = true, silent = true })

-- Window Navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Buffers
map("n", "H", ":bprevious<CR>", { silent = true, desc = "Previous Buffer" })
map("n", "L", ":bnext<CR>", { silent = true, desc = "Next Buffer" })
map("n", "<leader>x", ":bdelete<CR>", { silent = true, desc = "Close Buffer" })

-- UI Helpers
map("n", "<leader>e", ":Neotree toggle<CR>", { silent = true, desc = "Toggle File Explorer" })
map("n", "<leader>H", ":let bar = repeat('#', 60) | call append(line('.') - 1, bar) | call append(line('.'), bar)<CR>", { noremap = true, silent = true, desc = "Insert Horizontal Bar" })

-- Visual Mode Indentation
map("v", "<", "<gv", { silent = true, desc = "Indent Left" })
map("v", ">", ">gv", { silent = true, desc = "Indent Right" })

-- Move Lines (Alt + j/k)
map("n", "<A-j>", ":m .+1<CR>==", { silent = true, desc = "Move Line Down" })
map("n", "<A-k>", ":m .-2<CR>==", { silent = true, desc = "Move Line Up" })
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move Selection Down" })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move Selection Up" })
