-- claudecode.nvim: Claude Code IDE integration (diffs, selections, @-mentions)
require("claudecode").setup({
  terminal = {
    provider = "snacks",
    split_side = "right",
    split_width_percentage = 0.4,
    -- Window jumps straight out of the Claude pane. Only h/l: Claude uses
    -- <C-j> (newline) and <C-k> (kill line) itself.
    snacks_win_opts = {
      keys = {
        -- rhs must be a function: snacks treats a string rhs as an action name
        nav_h = {
          "<C-h>",
          function()
            vim.cmd.wincmd("h")
          end,
          mode = "t",
          desc = "Window left",
        },
        nav_l = {
          "<C-l>",
          function()
            vim.cmd.wincmd("l")
          end,
          mode = "t",
          desc = "Window right",
        },
      },
    },
  },
})

local map = vim.keymap.set
map("n", "<leader>ac", "<cmd>ClaudeCode<cr>", { desc = "Toggle Claude" })
map("n", "<leader>af", "<cmd>ClaudeCodeFocus<cr>", { desc = "Focus Claude" })
map("n", "<leader>ar", "<cmd>ClaudeCode --resume<cr>", { desc = "Resume Claude session" })
map("n", "<leader>aC", "<cmd>ClaudeCode --continue<cr>", { desc = "Continue Claude session" })
map("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Add buffer to Claude" })
map("x", "<leader>as", "<cmd>ClaudeCodeSend<cr>", { desc = "Send selection to Claude" })
map("n", "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", { desc = "Accept Claude diff" })
map("n", "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", { desc = "Reject Claude diff" })
