{ pkgs, ... }:
{
  home.packages = [ pkgs.herdr ];

  xdg.configFile."herdr/config.toml".text = ''
    # Managed by Home Manager - edit nix/programs/herdr/hm.nix instead.
    # Keybindings mirror nix/programs/tmux/hm.nix. Reload: herdr server reload-config

    # Pinned so herdr never needs to write back to this read-only file.
    onboarding = false

    [theme]
    name = "catppuccin"
    auto_switch = false

    [keys]
    prefix = "ctrl+a"

    # --- Splits ------------------------------------------------------------
    # NOTE: herdr names splits by divider orientation (vim-style), tmux names
    # them by the -h/-v flag. They are inverted; the KEYS below match tmux.
    split_vertical   = ["prefix+v", "prefix+\\", "prefix+|"]  # tmux: bind | \  split-window -h
    split_horizontal = "prefix+minus"                         # tmux: bind -     split-window -v

    # --- Pane lifecycle ------------------------------------------------------
    close_pane = "prefix+x"                                   # tmux: bind x     kill-pane
    close_tab  = "prefix+shift+x"                             # tmux: bind X     kill-window
    zoom       = "prefix+z"                                   # tmux default

    # --- Session / workspace lifecycle ---------------------------------------
    close_workspace = "prefix+q"                              # tmux: bind q     kill-session
    detach          = "prefix+d"                              # tmux default detach-client
                                                               # (moved off prefix+q)

    # --- Renaming --------------------------------------------------------------
    rename_tab       = "prefix+n"                             # tmux: bind n     rename-window
    rename_workspace = "prefix+shift+n"                       # tmux: bind N     rename-session
    rename_pane      = "prefix+shift+p"                       # herdr default

    # --- Creation ----------------------------------------------------------------
    new_tab       = "prefix+c"                                # tmux default new-window
    new_workspace = "prefix+shift+c"                          # moved off prefix+shift+n

    # tmux unbinds n/p for window cycling; alt+1..9 is the switcher instead.
    next_tab     = ""
    previous_tab = ""

    # --- Copy mode -----------------------------------------------------------
    copy_mode = ["prefix+esc", "prefix+up", "prefix+["]       # tmux: bind Escape/Up copy-mode -u

    # --- Pane focus / swap (vi keys) ------------------------------------------
    focus_pane_left  = "prefix+h"
    focus_pane_down  = "prefix+j"
    focus_pane_up    = "prefix+k"
    focus_pane_right = "prefix+l"
    swap_pane_left   = "prefix+shift+h"
    swap_pane_down   = "prefix+shift+j"
    swap_pane_up     = "prefix+shift+k"
    swap_pane_right  = "prefix+shift+l"

    # tmux binds C-h/C-j/C-k/C-l to one-shot `resize-pane ... 10`. herdr has no
    # one-shot resize action, only this modal equivalent (h/j/k/l inside it).
    resize_mode = "prefix+r"

    # --- Direct tab switching --------------------------------------------------
    switch_tab = ["prefix+1..9", "alt+1..9"]                  # tmux: bind -n M-1..M-9

    [ui]
    agent_panel_sort = "spaces"
  '';
}
