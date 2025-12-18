{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    # Enable Python support
    withPython3 = true;

    extraConfig = ''
      " Display Settings
      set number
      set relativenumber

      " Indentation Settings
      set expandtab
      set shiftwidth=4
      set tabstop=4
      set smartindent

      " Search Settings
      set ignorecase
      set smartcase
      set hlsearch
      set incsearch
    '';

    extraLuaConfig = ''
      -- ============================================================================
      -- CLIPBOARD CONFIGURATION (OSC 52 for remote sessions)
      -- ============================================================================

      -- Function to set OSC 52 clipboard
      local function set_osc52_clipboard()
        local function my_paste()
          local content = vim.fn.getreg '"'
          return vim.split(content, '\n')
        end

        vim.g.clipboard = 'osc52'
      end

      -- Schedule the setting after `UiEnter` because it can increase startup-time.
      vim.schedule(function()
        vim.opt.clipboard:append 'unnamedplus'

        -- Standard SSH session handling
        if vim.uv.os_getenv 'SSH_CLIENT' ~= nil or vim.uv.os_getenv 'SSH_TTY' ~= nil then
          set_osc52_clipboard()
        end
      end)
    '';
  };
}
