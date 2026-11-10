-- nvim-treesitter (main branch): parsers come from Nix (withAllGrammars),
-- so only highlighting/indent/folds need wiring up per buffer.
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    if not pcall(vim.treesitter.start, args.buf) then
      return
    end
    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    vim.wo.foldmethod = "expr"
    vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  end,
})

require("nvim-treesitter-textobjects").setup({
  select = { lookahead = true },
  move = { set_jumps = true },
})

local select = require("nvim-treesitter-textobjects.select")
for key, query in pairs({
  ["af"] = "@function.outer",
  ["if"] = "@function.inner",
  ["ac"] = "@class.outer",
  ["ic"] = "@class.inner",
  ["aa"] = "@parameter.outer",
  ["ia"] = "@parameter.inner",
}) do
  vim.keymap.set({ "x", "o" }, key, function()
    select.select_textobject(query, "textobjects")
  end, { desc = "TS " .. query })
end

local move = require("nvim-treesitter-textobjects.move")
for key, spec in pairs({
  ["]f"] = { move.goto_next_start, "@function.outer" },
  ["[f"] = { move.goto_previous_start, "@function.outer" },
  ["]a"] = { move.goto_next_start, "@parameter.inner" },
  ["[a"] = { move.goto_previous_start, "@parameter.inner" },
}) do
  vim.keymap.set({ "n", "x", "o" }, key, function()
    spec[1](spec[2], "textobjects")
  end, { desc = "TS move " .. spec[2] })
end
