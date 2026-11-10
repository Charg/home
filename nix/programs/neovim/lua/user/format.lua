local conform = require("conform")

-- Filetypes formatted automatically on save. Others (yaml, markdown, ...)
-- only format on demand with <leader>cf to avoid churning existing files.
local on_save = {
  nix = true,
  lua = true,
  sh = true,
  bash = true,
  python = true,
  terraform = true,
  ["terraform-vars"] = true,
  hcl = true,
  toml = true,
}

conform.setup({
  formatters_by_ft = {
    nix = { "nixfmt" },
    lua = { "stylua" },
    sh = { "shfmt" },
    bash = { "shfmt" },
    python = { "ruff_organize_imports", "ruff_format" },
    terraform = { "tofu_fmt" },
    ["terraform-vars"] = { "tofu_fmt" },
    hcl = { "tofu_fmt" },
    toml = { "taplo" },
    yaml = { "prettierd" },
    json = { "prettierd" },
    jsonc = { "prettierd" },
    markdown = { "prettierd" },
  },
  formatters = {
    shfmt = { prepend_args = { "-i", "2", "-ci" } },
  },
  default_format_opts = { lsp_format = "fallback" },
  format_on_save = function(bufnr)
    if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
      return
    end
    if on_save[vim.bo[bufnr].filetype] then
      return { timeout_ms = 1000 }
    end
  end,
})

vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

vim.keymap.set({ "n", "x" }, "<leader>cf", function()
  conform.format({ async = true })
end, { desc = "Format buffer/selection" })

vim.keymap.set("n", "<leader>cF", function()
  vim.g.disable_autoformat = not vim.g.disable_autoformat
  vim.notify("Format on save " .. (vim.g.disable_autoformat and "disabled" or "enabled"))
end, { desc = "Toggle format on save" })
