{ lib, ... }:

# Memory protection: zram + earlyoom + systemd-oomd + user.slice throttle.
# Why: pnpm dev (Next.js 16, Firebase emulators) + multiple claude sessions can
# push the 32 GB system past its ceiling and freeze the compositor. earlyoom
# kills the worst Node process before that happens; oomd is a swap-only backstop;
# user.slice MemoryHigh keeps the system slice (Hyprland, pipewire) responsive.
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
    freeSwapThreshold = 20;
    freeSwapKillThreshold = 10;
    enableNotifications = true;
    reportInterval = 0;
    extraArgs = [
      "--prefer" "^(node|next-server|esbuild|tsc|tsserver|webpack|vite|turbo|firebase|java)$"
      "--avoid"  "^(systemd|Hyprland|sshd|dbus-daemon|pipewire|wireplumber|claude|nvim|code|kitty|mako|waybar|hyprlock)$"
      "-g"
    ];
  };

  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
    enableRootSlice = false;
    enableSystemSlice = false;
    settings.OOM = {
      DefaultMemoryPressureDurationSec = "20s";
    };
  };

  systemd.slices."user".sliceConfig = {
    MemoryHigh = "28G";
    ManagedOOMSwap = "kill";
    # NixOS's systemd.oomd.enableUserSlices=true would otherwise inject
    # ManagedOOMMemoryPressure=kill (at 80% PSI). That picks the highest-pressure
    # *cgroup* — could be the GUI session — ignoring earlyoom's --prefer/--avoid.
    # We disable pressure-kill here and rely on earlyoom for selective kills.
    ManagedOOMMemoryPressure = lib.mkForce "auto";
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };
}
