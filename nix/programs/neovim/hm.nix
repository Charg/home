{ config, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withPython3 = false;
    withRuby = false;
    withNodeJs = false;

    plugins = with pkgs.vimPlugins; [
      # Core
      nvim-treesitter.withAllGrammars
      nvim-treesitter-textobjects
      nvim-lspconfig
      SchemaStore-nvim
      lazydev-nvim
      vim-helm

      # Completion
      blink-cmp
      friendly-snippets

      # Formatting
      conform-nvim

      # Navigation / UI
      snacks-nvim
      oil-nvim
      trouble-nvim
      which-key-nvim
      lualine-nvim
      nvim-web-devicons
      fidget-nvim
      todo-comments-nvim
      tokyonight-nvim
      mini-nvim

      # Git
      gitsigns-nvim
      diffview-nvim

      # AI
      claudecode-nvim
    ];

    # Language servers, formatters and tools available only inside nvim
    extraPackages = with pkgs; [
      ripgrep
      fd
      lazygit

      # LSP
      yaml-language-server
      helm-ls
      nixd
      tofu-ls
      bash-language-server
      basedpyright
      ruff
      marksman
      lua-language-server
      taplo
      vscode-langservers-extracted
      dockerfile-language-server
      gopls

      # Formatters / linters
      nixfmt
      stylua
      shfmt
      shellcheck
      prettierd
      opentofu
    ];

    initLua = ''
      vim.g.nix_flake = "${config.home.homeDirectory}/code/home"
      require("user")
    '';
  };

  xdg.configFile."nvim/lua/user".source = ./lua/user;
}
