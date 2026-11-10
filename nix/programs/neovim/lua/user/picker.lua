require("snacks").setup({
  bigfile = { enabled = true },
  quickfile = { enabled = true },
  indent = { enabled = true },
  input = { enabled = true },
  notifier = { enabled = true },
  picker = { enabled = true },
  scope = { enabled = true },
  terminal = { enabled = true },
  words = { enabled = true },
})

local map = vim.keymap.set
local P = function(name, opts)
  return function()
    Snacks.picker[name](opts)
  end
end

-- Find
map("n", "<leader><space>", P("smart"), { desc = "Smart find files" })
map("n", "<leader>ff", P("files"), { desc = "Find files" })
map("n", "<leader>fg", P("git_files"), { desc = "Find git files" })
map("n", "<leader>fb", P("buffers"), { desc = "Buffers" })
map("n", "<leader>fr", P("recent"), { desc = "Recent files" })
map("n", "<leader>fc", P("files", { cwd = vim.fn.stdpath("config") }), { desc = "Find config file" })

-- Search
map("n", "<leader>/", P("grep"), { desc = "Grep" })
map("n", "<leader>sg", P("grep"), { desc = "Grep" })
map({ "n", "x" }, "<leader>sw", P("grep_word"), { desc = "Grep word/selection" })
map("n", "<leader>sb", P("lines"), { desc = "Buffer lines" })
map("n", "<leader>sd", P("diagnostics"), { desc = "Diagnostics" })
map("n", "<leader>sh", P("help"), { desc = "Help pages" })
map("n", "<leader>sk", P("keymaps"), { desc = "Keymaps" })
map("n", "<leader>sr", P("resume"), { desc = "Resume last picker" })
map("n", "<leader>st", function()
  Snacks.picker.todo_comments()
end, { desc = "TODOs" })
map("n", "<leader>n", function()
  Snacks.notifier.show_history()
end, { desc = "Notification history" })

-- Terminal
map({ "n", "t" }, "<C-/>", function()
  Snacks.terminal()
end, { desc = "Toggle terminal" })

-- Jump between LSP references of word under cursor
map("n", "]]", function()
  Snacks.words.jump(vim.v.count1)
end, { desc = "Next reference" })
map("n", "[[", function()
  Snacks.words.jump(-vim.v.count1)
end, { desc = "Prev reference" })
