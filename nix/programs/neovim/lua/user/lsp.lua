-- Server binaries are provided by Nix (programs.neovim.extraPackages);
-- nvim-lspconfig supplies the default config for each name below.

require("lazydev").setup({})

local flake = vim.g.nix_flake or vim.fn.expand("~/code/home")
local host = vim.fn.hostname()

vim.lsp.config("nixd", {
  settings = {
    nixd = {
      nixpkgs = { expr = ('import (builtins.getFlake "%s").inputs.nixpkgs { }'):format(flake) },
      formatting = { command = { "nixfmt" } },
      options = {
        nixos = {
          expr = ('(builtins.getFlake "%s").nixosConfigurations.%s.options'):format(flake, host),
        },
        home_manager = {
          expr = ('(builtins.getFlake "%s").homeConfigurations."%s@%s".options'):format(
            flake,
            vim.env.USER or "",
            host
          ),
        },
      },
    },
  },
})

vim.lsp.config("yamlls", {
  settings = {
    redhat = { telemetry = { enabled = false } },
    yaml = {
      schemaStore = { enable = false, url = "" },
      schemas = vim.tbl_extend("force", require("schemastore").yaml.schemas(), {
        kubernetes = { "kube/**/*.yaml", "k8s/**/*.yaml", "manifests/**/*.yaml" },
      }),
      kubernetesCRDStore = { enable = true },
      validate = true,
      format = { enable = false }, -- conform/prettierd handles formatting
    },
  },
})

vim.lsp.config("jsonls", {
  settings = {
    json = {
      schemas = require("schemastore").json.schemas(),
      validate = { enable = true },
    },
  },
})

vim.lsp.config("basedpyright", {
  settings = { basedpyright = { analysis = { typeCheckingMode = "standard" } } },
})

vim.lsp.enable({
  "nixd",
  "yamlls",
  "helm_ls",
  "tofu_ls",
  "bashls",
  "basedpyright",
  "ruff",
  "markdown_oxide",
  "lua_ls",
  "taplo",
  "jsonls",
  "dockerls",
  "gopls",
})

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { spacing = 2, source = "if_many" },
  float = { source = "if_many" },
  signs = true,
  underline = true,
})

-- Buffer-local keymaps once a server attaches.
-- Neovim defaults already provide: K (hover), grn (rename), gra (code action),
-- grr (references), gri (implementation), gO (symbols), [d / ]d (diagnostics).
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local function map(lhs, rhs, desc, mode)
      vim.keymap.set(mode or "n", lhs, rhs, { buffer = args.buf, desc = desc })
    end

    map("gd", function()
      Snacks.picker.lsp_definitions()
    end, "Goto definition")
    map("gD", vim.lsp.buf.declaration, "Goto declaration")
    map("gy", function()
      Snacks.picker.lsp_type_definitions()
    end, "Goto type definition")
    map("grr", function()
      Snacks.picker.lsp_references()
    end, "References")
    map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
    map("<leader>ca", vim.lsp.buf.code_action, "Code action", { "n", "x" })
    map("<leader>ss", function()
      Snacks.picker.lsp_symbols()
    end, "Document symbols")
    map("<leader>sS", function()
      Snacks.picker.lsp_workspace_symbols()
    end, "Workspace symbols")

    if client and client:supports_method("textDocument/inlayHint") then
      map("<leader>ch", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = args.buf }), { bufnr = args.buf })
      end, "Toggle inlay hints")
    end

    -- ruff handles lint/format; let basedpyright own hover
    if client and client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end
  end,
})
