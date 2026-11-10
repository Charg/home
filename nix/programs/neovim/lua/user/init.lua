vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

for _, mod in ipairs({
  "options",
  "keymaps",
  "ui",
  "treesitter",
  "lsp",
  "completion",
  "format",
  "picker",
  "editor",
  "git",
  "ai",
}) do
  local ok, err = pcall(require, "user." .. mod)
  if not ok then
    vim.notify(("user.%s failed to load:\n%s"):format(mod, err), vim.log.levels.ERROR)
  end
end
