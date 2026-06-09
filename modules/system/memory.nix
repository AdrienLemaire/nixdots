{ ... }:

# Memory protection: zram + earlyoom + app.slice containment.
# Why: next/pnpm dev + Firebase emulators + multiple claude sessions can push the
# 32 GB system past its ceiling. History: on 2026-06-09 systemd-oomd's cgroup-level
# kill (ManagedOOMSwap) SIGKILLed the whole GUI session (session-3.scope) — both oomd
# kill paths ignore earlyoom's --prefer/--avoid, and the compositor's scope (sharing
# space with firefox) was the fattest cgroup, so oomd kept targeting it.
# Strategy now:
#   - earlyoom is the SOLE selective killer (protects Hyprland/claude, prefers node).
#   - oomd no longer manages user cgroups at all (kernel OOM is the final backstop).
#   - a soft MemoryHigh on app.slice throttles the GUI/app group before it can starve
#     the rest; it never SIGKILLs.
# Agent-session resilience (surviving logout / compositor crash) is handled in
# user space by a plain tmux server started via the `cz` shell helper — NOT a systemd
# service, because a service-launched tmux gets systemd's minimal PATH and can't find
# claude/node/etc. tmux daemonizes and (with linger enabled) outlives the session.
{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 10;
    freeMemKillThreshold = 5;
    freeSwapThreshold = 25; # act a little earlier on swap now that earlyoom is the
    freeSwapKillThreshold = 15; # sole killer (oomd no longer kills user cgroups).
    enableNotifications = true;
    reportInterval = 0;
    extraArgs = [
      "--prefer" "^(node|next-server|esbuild|tsc|tsserver|webpack|vite|turbo|firebase|java)$"
      "--avoid" "^(systemd|Hyprland|sshd|dbus-daemon|pipewire|wireplumber|claude|nvim|code|kitty|mako|waybar|hyprlock)$"
      "-g"
    ];
  };

  # systemd-oomd does whole-cgroup kills that ignore earlyoom's policy and kept
  # targeting the GUI session (the fattest cgroup). Disable oomd management of ALL
  # cgroups — both the swap and the memory-pressure kill paths, on system AND user
  # slices — and rely on earlyoom for selective, policy-aware kills.
  systemd.oomd = {
    enable = true;
    enableUserSlices = false;
    enableRootSlice = false;
    enableSystemSlice = false;
  };

  # Soft memory ceiling for the whole user tree, keeping system.slice (sshd, pipewire,
  # nix-daemon) responsive. MemoryHigh throttles + reclaims; it never SIGKILLs.
  systemd.slices."user".sliceConfig.MemoryHigh = "28G";

  # Contain the GUI/app group (ghostty + the tmux server/agents it hosts, and — once
  # the UWSM session is active — firefox) so a runaway can't starve the rest. Soft cap.
  systemd.user.slices."app".sliceConfig.MemoryHigh = "20G";

  boot.kernel.sysctl = {
    "vm.swappiness" = 130;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };
}
