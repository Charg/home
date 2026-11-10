-- oil: edit the filesystem like a buffer
require("oil").setup({
  view_options = { show_hidden = true },
  keymaps = { ["<C-h>"] = false, ["<C-l>"] = false }, -- keep window navigation
})
vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory" })

-- trouble: diagnostics / quickfix lists
require("trouble").setup({})
local map = vim.keymap.set
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Workspace diagnostics" })
map("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer diagnostics" })
map("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix list" })
map("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Symbols outline" })

require("todo-comments").setup({})

-- mini.nvim modules
require("mini.ai").setup({ n_lines = 500 })
require("mini.surround").setup() -- sa / sd / sr
require("mini.pairs").setup()
require("mini.tabline").setup() -- buffer list along the top
