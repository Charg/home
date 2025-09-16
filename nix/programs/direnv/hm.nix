{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true; # see note on other shells below
    nix-direnv.enable = true;
  };

  home.file.".direnvrc".text = ''
    layout_uv() {
      watch_file .python-version pyproject.toml uv.lock
      uv sync --frozen || true
      venv_path="$(expand_path "''${UV_PROJECT_ENVIRONMENT:-.venv}")"
      if [[ -e $venv_path ]]; then
          VIRTUAL_ENV="$(pwd)/.venv"
          PATH_add "$VIRTUAL_ENV/bin"
          export UV_ACTIVE=1  # or VENV_ACTIVE=1
          export VIRTUAL_ENV
      fi
      if [[ ! -e $venv_path ]]; then
          log_status "No virtual environment exists. Executing \`uv venv\` to create one."
      fi
    }
  '';
}
