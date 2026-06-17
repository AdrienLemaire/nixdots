{ pkgs, ... }:

{
  home.packages = [
    pkgs.fzf # required by tmux-fzf and extrakto
    pkgs.wl-clipboard # wl-copy/wl-paste for yank on Wayland
  ];

  # Persistent multiplexer for Claude agent sessions. The server runs as the
  # tmux-main user service in agents.slice (modules/system/memory.nix) so no
  # ghostty/compositor scope death can reach it; the drop-ins below neutralize
  # ghostty's hardcoded oomd kill property and harden the per-pane scopes.
  # secureSocket=false puts the socket in /tmp so the server outlives the
  # /run/user lifetime; with linger enabled it survives a forced logout.
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
        # On a fresh server start, resurrect's restore may collide with the service's
        # pre-created blank 'main' session (duplicate or layout overlay, depending on
        # resurrect version). Bounded nuisance: kill the blank one if it appears.
        extraConfig = ''
          set -g @continuum-save-interval '15'
          set -g @continuum-restore 'on'
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

      # Claude Code sets the terminal title to its current task; tmux stores it as
      # the pane title (#T). Forward it to the outer terminal tab, and show it in
      # the window list for windows tagged by the claude/claude2 zsh wrappers
      # (@claude_acct carries a colored per-account marker).
      set -g set-titles on
      set -g set-titles-string "#S:#I #T"

      # Carry WAYLAND_DISPLAY into panes so wl-copy/wl-paste (and Claude Code's
      # image paste, which shells out to wl-paste) can reach the compositor.
      # tmux's default update-environment omits it, and this server is a
      # long-lived user service (tmux-main) that outlives compositor restarts —
      # so refresh-from-client-on-attach (-ga, append) is correct over a
      # hardcoded value, and must not clobber DISPLAY/SSH_AUTH_SOCK/etc.
      set -ga update-environment WAYLAND_DISPLAY

      # Same rationale for Hyprland's per-instance signature: `hyprctl` needs it,
      # but tmux-main and panes that predate a compositor restart don't carry it,
      # so `hyprctl reload` fails with "HYPRLAND_INSTANCE_SIGNATURE not set".
      # Refresh it from the attaching client (a compositor-launched terminal
      # always has the current value).
      set -ga update-environment HYPRLAND_INSTANCE_SIGNATURE

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
          set -g window-status-format " #I #{?#{@claude_acct},#{?#{==:#{@claude_acct},A},#[fg=green],#[fg=magenta]}#{@claude_acct}#[default] #{?#{pane_title},#{=20:pane_title},#W},#W} " ; \
          set -g window-status-current-format "#[fg=#1e1e2e,bg=#cba6f7,bold] #I #{?#{@claude_acct},#{@claude_acct} #{?#{pane_title},#{=20:pane_title},#W},#W} #[default]" ; \
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

  # ghostty (linux-cgroup=always) hardcodes ManagedOOMMemoryPressure=kill on
  # every app-ghostty-surface-transient-*.scope (src/apprt/gtk/cgroup.zig; no
  # config option). Under global thrash, oomd then kills inside the surface
  # scope and systemd tears the whole cgroup down — this is what used to take
  # the tmux server (and every claude session) with it. Prefix drop-ins apply
  # to transient units and are parsed after the transient fragment, so this
  # override wins. linux-cgroup=always itself stays: per-surface isolation is
  # useful once tmux is out of the blast radius.
  # Note: 'auto' is safe here only because enableUserSlices=false in
  # modules/system/memory.nix prevents any ancestor slice from opting into
  # ManagedOOMMemoryPressure=kill. If that ever changes, switch this to
  # ManagedOOMMemoryPressureLimit=100% instead.
  xdg.configFile."systemd/user/app-ghostty-surface-transient-.scope.d/50-no-oomd-kill.conf".text = ''
    [Scope]
    ManagedOOMMemoryPressure=auto
  '';

  # Per-pane hardening for tmux's native tmux-spawn-<uuid>.scope units (panes
  # inherit the server's slice = agents.slice). OOMPolicy=continue: a
  # kernel-OOM kill of one child must not fail the scope (pane scopes set
  # SendSIGHUP=yes — a scope stop would HUP the whole pane). MemoryHigh
  # reclaim-throttles a single runaway claude pane before it starves siblings.
  xdg.configFile."systemd/user/tmux-spawn-.scope.d/50-agents.conf".text = ''
    [Scope]
    OOMPolicy=continue
    MemoryHigh=12G
  '';
}
