{ pkgs, ... }:

# Memory & agent-session protection: zram + disk tier + earlyoom + MGLRU backstop.
# History:
#   - 2026-06-09: systemd-oomd's cgroup-level kill SIGKILLed the whole GUI
#     session; oomd was disabled for user/root/system slices (kept below).
#   - 2026-06-12: diagnosed the remaining daily failures (see
#     docs/superpowers/specs/2026-06-12-claude-session-stability-design.md):
#     ghostty hardcodes ManagedOOMMemoryPressure=kill on its surface scopes
#     (neutralized by a drop-in shipped from modules/hm/tmux.nix); the tmux
#     server used to live inside such a scope (now the tmux-main user service
#     in agents.slice, below); the daily freeze was a reclaim livelock that
#     earlyoom's thresholds could never reach (thresholds raised, MGLRU
#     min_ttl backstop and a disk swap tier added); and earlyoom's regexes
#     matched almost nothing (comm names are wrapper-mangled and truncated to
#     15 chars).
# Strategy:
#   - earlyoom is the polite first line: prefers discord/firefox/dev tooling,
#     avoids claude/tmux/ghostty/UI, fires while the system is still usable.
#   - MGLRU min_ttl_ms converts a reclaim livelock into a kernel OOM kill
#     (largest-RSS victim — usually the fattest claude pane; acceptable last
#     resort: the tmux server survives, the pane recovers via claude --resume).
#   - agents.slice holds the tmux server and all tmux-spawn pane scopes
#     (panes inherit the server's slice); per-pane MemoryHigh lives in a
#     tmux-spawn-.scope.d drop-in (modules/hm/tmux.nix).
#   - zram is the hot swap tier; the low-priority NVMe swapfile lets truly
#     cold anon pages leave RAM entirely (zram's effective ratio measured
#     ~1.68:1 on this box — compressed pages cost real RAM).
{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  # Cold tier behind zram (prio 10 < 100): idle agent/browser heaps age out
  # of RAM instead of staying compressed-resident forever.
  swapDevices = [
    {
      device = "/swapfile";
      size = 24 * 1024; # MiB
      priority = 10;
    }
  ];

  services.earlyoom = {
    enable = true;
    # The old 10/5 + 25/15 pair was unreachable in the thrash regime (freezes
    # happened at ~70% zram full = 30% free swap). Fire while there is slack.
    freeMemThreshold = 15;
    freeMemKillThreshold = 8;
    freeSwapThreshold = 50;
    freeSwapKillThreshold = 30;
    enableNotifications = true;
    reportInterval = 1800;
    # comm names are truncated to 15 chars and most binaries here are NixOS
    # wrappers (".foo-wrapped"). No -g: a group kill on a node victim could
    # take a claude session with it. No bare "node" in prefer: claude's MCP
    # servers are node processes. Hyprland is neutral on purpose — in the
    # avoid band it would outrank a 14G claude pane as a survivor; neutral
    # means it dies after discord/firefox/dev servers but before anything
    # avoided. Desired order: discord -> firefox -> hyprland -> agents.
    extraArgs = [
      "--prefer" "^(\\.Discord-wrappe|Discord|firefox|Isolated Web Co|Web Content|next-server|esbuild|tsserver|jest|java|webpack|vite|turbo)"
      "--avoid" "^(systemd|sshd|dbus|pipewire|wireplumber|claude|nvim|tmux: server|tmux: client|\\.ghostty-wrappe|\\.waybar-wrapped|\\.dunst-wrapped|hyprlock)$"
    ];
  };

  # oomd stays out of user space (2026-06-09 incident). ghostty re-opts its
  # own surface scopes in; that is overridden by the
  # app-ghostty-surface-transient- prefix drop-in from modules/hm/tmux.nix.
  systemd.oomd = {
    enable = true;
    enableUserSlices = false;
    enableRootSlice = false;
    enableSystemSlice = false;
  };

  # MGLRU anti-thrash backstop: never reclaim a working set younger than 1s;
  # OOM-kill instead of livelocking. Replaces the daily freeze with a single
  # kill. Lower to 500 if kills feel too eager.
  systemd.tmpfiles.rules = [
    "w /sys/kernel/mm/lru_gen/min_ttl_ms - - - - 1000"
  ];

  # Agent tree: tmux server + every tmux-spawn-*.scope pane. Soft collective
  # cap. app.slice (GUI apps incl. ghostty/firefox) keeps its own. The old
  # user.slice MemoryHigh=28G is gone: at 28G/30G it protected nothing and
  # only added direct-reclaim stalls near the ceiling.
  systemd.user.slices."agents".sliceConfig.MemoryHigh = "22G";
  systemd.user.slices."app".sliceConfig.MemoryHigh = "20G";

  # The tmux server gets its own service so no terminal/compositor scope
  # death can reach it. `zsh -lc` provides the full NixOS PATH (the old
  # objection to a service-launched tmux); pane shells are interactive zsh
  # and rebuild their own env anyway. NixOS-side user units are not restarted
  # by nixos-rebuild, so rebuilds cannot kill the server. With linger enabled
  # the service also starts at boot and survives logout.
  systemd.user.services.tmux-main = {
    description = "tmux server for agent sessions";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "forking";
      ExecStart = "${pkgs.zsh}/bin/zsh -lc 'tmux has-session -t main 2>/dev/null || exec tmux new-session -d -s main'";
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "agents.slice";
      # Rare edge: if a main session already exists while this unit is
      # inactive (server created via cz's fallback path), the has-session
      # guard exits without forking and Type=forking may record a protocol
      # failure with a short restart burst. Benign and rate-limited; cz still
      # attaches. Accepted over Type=oneshot, which would lose
      # Restart=on-failure tracking of real server deaths.
      # A kernel-OOM kill of one child (an MCP server, a build) must not
      # stop the whole unit.
      OOMPolicy = "continue";
    };
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 100; # was 130 (zram-only tuning; now there is a disk tier)
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };
}
