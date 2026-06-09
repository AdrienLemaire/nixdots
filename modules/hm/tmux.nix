{ pkgs, ... }:

{
  home.packages = [
    pkgs.fzf # required by tmux-fzf and extrakto
    pkgs.wl-clipboard # wl-copy/wl-paste for yank on Wayland
  ];

  # Persistent multiplexer for Claude agent sessions (see modules/system/memory.nix).
  # secureSocket=false puts the socket in /tmp so the server outlives the /run/user
  # lifetime; with linger enabled the `cz` session survives a forced logout.
  programs.tmux = {
    enable = true;
    secureSocket = false;
    terminal = "tmux-256color";
    escapeTime = 10;
    historyLimit = 50000;
    mouse = true;
    baseIndex = 1;
    keyMode = "vi";
    focusEvents = true; # needed by vim-tmux-navigator and resurrect

    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator # C-h/j/k/l across nvim splits and tmux panes
      yank # copy to system clipboard (uses wl-copy on Wayland)
      extrakto # prefix+Tab: fzf-grab paths/urls/words off the screen
      tmux-fzf # prefix+F: fuzzy session/window/pane switcher
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-save-interval '15'
          set -g @continuum-restore 'off'
        '';
      }
      {
        plugin = tmux-which-key;
        # NixOS: the plugin's autobuild copies into its (read-only) store dir and
        # fails. XDG mode relocates config + built init under ~/.config and
        # ~/.local/share. Must be set before the plugin loads — this block is
        # emitted immediately before its run-shell.
        extraConfig = ''
          set -g @tmux-which-key-xdg-enable 1
        '';
      }
    ];

    extraConfig = ''
      # Renumber windows sequentially when one is closed (base-index/pane-base-index
      # come from baseIndex above).
      set -g renumber-windows on

      # Keep CWD when splitting/creating windows
      bind '"' split-window -v -c "#{pane_current_path}"
      bind '%' split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"

      # --- Theme: follow HyDE (wallbash) with a Mocha first-run fallback ---
      # The wallbash template regenerates ~/.cache/hyde/wallbash/tmux.conf on every
      # theme/wallpaper switch and re-sources it into the running server.
      if-shell '[ -f ~/.cache/hyde/wallbash/tmux.conf ]' \
        'source-file ~/.cache/hyde/wallbash/tmux.conf' \
        ' \
          set -g status on ; \
          set -g status-justify left ; \
          set -g status-style "bg=#1e1e2e,fg=#cdd6f4" ; \
          set -g status-left-length 40 ; \
          set -g status-left "#[fg=#1e1e2e,bg=#cba6f7,bold] #S #[default] " ; \
          set -g window-status-format " #I #W " ; \
          set -g window-status-current-format "#[fg=#1e1e2e,bg=#cba6f7,bold] #I #W #[default]" ; \
          set -g window-status-separator "" ; \
          set -g status-right-length 60 ; \
          set -g status-right "#[fg=#b4befe] %Y-%m-%d #[fg=#1e1e2e,bg=#cba6f7,bold] %H:%M " ; \
          set -g pane-border-style "fg=#313244" ; \
          set -g pane-active-border-style "fg=#cba6f7" ; \
          set -g message-style "bg=#cba6f7,fg=#1e1e2e" ; \
          set -g message-command-style "bg=#cba6f7,fg=#1e1e2e" ; \
          set -g mode-style "bg=#cba6f7,fg=#1e1e2e" \
        '
    '';
  };
}
