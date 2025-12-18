{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    aggressiveResize = true;
    historyLimit = 500000;
    keyMode = "vi";
    shortcut = "a";
    terminal = "screen-256color";
    plugins = with pkgs; [
      tmuxPlugins.sensible
    ];
    extraConfig = ''
      # set -s (server) - Options apply to the entire tmux server instance, affecting core behaviors.
      # set -g (global) - Options apply across all relevant sessions or windows, acting as defaults that individual sessions/windows can override.
      # set -w (window) - Options specific to all windows within a particular session

      # Server level tmux options
      set -s set-clipboard on

      # Ensure tmux loads the correct shell
      set -gu default-command
      set -g default-shell "$SHELL"

      # Ensure SSH variables are updated when a new client connects
      set-option -g update-environment "SSH_CLIENT SSH_TTY"

      set -g base-index 1
      set -g pane-base-index 1

      set -g status-keys vi
      set -g renumber-windows on	      # auto renumber windows when a window is closed
      set -sg escape-time 10                  # Set the escape-time to 10ms. Allows quick escapes when using vim in tmux
      setw -g mode-keys vi
      setw -g mouse on
      setw -g monitor-activity on
      set-window-option -g allow-rename off   # Dont auto rename window sessions after a command is run
      set-option -g visual-activity on        # Enable window notifications

      # remove key bindings
      unbind %      # Split screen
      unbind ,      # Name a window
      unbind .      # Move current window to index
      unbind n      # Next window
      unbind p      # Previous window
      unbind [      # Enter copy mode
      unbind l      # Move to the previously selected window

      # keybindings
      bind-key -T copy-mode-vi v send-keys -X begin-selection	               # VI like copy experience
      bind-key -T copy-mode-vi y send-keys -X copy-selection 	               # VI like copy experience
      bind-key a      send-prefix			                       # Send prefix through to terminal
      bind-key |      split-window -h			                       # Horizontal Split
      bind-key \      split-window -h			                       # Horizontal Split - Easier to type
      bind-key -      split-window -v			                       # Vertical Split
      bind-key space  next-layout
      bind-key x      kill-pane                                                # Kill the current pane
      bind-key X      kill-window                                              # Kill entire window - all panes
      bind-key q      confirm-before kill-session                              # Quit safely. Kills current session
      bind-key Q      confirm-before kill-server                               # Quit safely. Kills all sessions
      bind-key <      swap-window -t :-                                        # Move window to the right
      bind-key >      swap-window -t :+                                        # Move window to the left
      bind-key n      command-prompt "rename-window %%"                        # Rename window
      bind-key N      command-prompt "rename-session %%"                       # Rename session
      bind-key Escape copy-mode -u                                             # Enter copy mode
      bind-key Up     copy-mode -u					       # Enter copy mode
      bind-key C-h    resize-pane -L 10                                        # Resize pane to the right 10 cells
      bind-key C-l    resize-pane -R 10                                        # Resize pane to the left 10 cells
      bind-key C-j    resize-pane -D 10                                        # Resize pane to down 10 cells
      bind-key C-k    resize-pane -U 10                                        # Resize pane to up 10 cells
      bind-key C-c    run -b "tmux save-buffer - | xclip -i -sel clipboard*"   # Copy current buffer to clibboard
      bind-key -n M-1 select-window -t 1                                       # switch windows using alt+number
      bind-key -n M-2 select-window -t 2                                       # switch windows using alt+number
      bind-key -n M-3 select-window -t 3                                       # switch windows using alt+number
      bind-key -n M-4 select-window -t 4                                       # switch windows using alt+number
      bind-key -n M-5 select-window -t 5                                       # switch windows using alt+number
      bind-key -n M-6 select-window -t 6                                       # switch windows using alt+number
      bind-key -n M-7 select-window -t 7                                       # switch windows using alt+number
      bind-key -n M-8 select-window -t 8                                       # switch windows using alt+number
      bind-key -n M-9 select-window -t 9                                       # switch windows using alt+number
    '';
  };
}
