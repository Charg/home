local o = vim.opt

-- Display
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.scrolloff = 8
o.sidescrolloff = 8
o.wrap = false
o.termguicolors = true
o.showmode = false -- lualine shows it
o.splitright = true
o.splitbelow = true
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
o.winborder = "rounded"

-- Indentation
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.shiftround = true

-- Search
o.ignorecase = true
o.smartcase = true
o.hlsearch = true
o.incsearch = true
o.inccommand = "split"

-- Behaviour
o.mouse = "a"
o.undofile = true
o.updatetime = 250
o.timeoutlen = 400
o.confirm = true
o.completeopt = { "menu", "menuone", "noselect" }
o.foldlevelstart = 99

-- Two-space indent for config-ish languages
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "nix", "lua", "yaml", "helm", "json", "jsonc", "markdown", "terraform", "hcl", "sh", "bash", "zsh" },
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Restore cursor position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local lines = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= lines and vim.bo[args.buf].filetype ~= "gitcommit" then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Clipboard: system clipboard everywhere, OSC 52 when the terminal is remote
-- (SSH, or a herdr pane on a machine with no local display session)
vim.schedule(function()
  vim.opt.clipboard:append("unnamedplus")
  local ssh = vim.env.SSH_CLIENT or vim.env.SSH_TTY
  local herdr_headless = vim.env.HC_TERMINAL_SOCKET
    and not (vim.env.WAYLAND_DISPLAY or vim.env.DISPLAY)
  if ssh or herdr_headless then
    vim.g.clipboard = "osc52"
  end
end)
