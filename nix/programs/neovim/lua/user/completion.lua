require("blink.cmp").setup({
  keymap = { preset = "default" }, -- <C-y> accept, <C-n>/<C-p> navigate, <C-space> open
  appearance = { nerd_font_variant = "mono" },
  completion = {
    documentation = { auto_show = true, auto_show_delay_ms = 300 },
  },
  signature = { enabled = true },
  sources = {
    default = { "lazydev", "lsp", "path", "snippets", "buffer" },
    providers = {
      lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
    },
  },
  fuzzy = { implementation = "prefer_rust" },
})
