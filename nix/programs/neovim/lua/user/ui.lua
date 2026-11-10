require("tokyonight").setup({ style = "night" })
vim.cmd.colorscheme("tokyonight")

require("nvim-web-devicons").setup()

require("lualine").setup({
  options = {
    theme = "tokyonight",
    globalstatus = true,
    component_separators = "|",
    section_separators = "",
  },
  sections = {
    lualine_c = { { "filename", path = 1 } },
    lualine_x = { "diagnostics", "filetype" },
  },
})

require("fidget").setup({})

local wk = require("which-key")
wk.setup({ preset = "modern" })
wk.add({
  { "<leader>a", group = "ai (claude)" },
  { "<leader>b", group = "buffer" },
  { "<leader>c", group = "code" },
  { "<leader>f", group = "find" },
  { "<leader>g", group = "git" },
  { "<leader>s", group = "search" },
  { "<leader>x", group = "diagnostics" },
})
