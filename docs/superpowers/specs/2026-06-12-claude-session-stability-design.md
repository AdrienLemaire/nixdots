# Claude Code Session Stability — Design

Date: 2026-06-12
Scope approved: Phase 1 (protect tmux/claude), Phase 3 (anti-freeze), Phase 4
(claude resource gating). Phase 2 (discord/firefox kill ordering via dedicated
slices) was explicitly dropped by the user.

## Problem

Daily freezes and loss of all Claude Code sessions. tmux dies before discord,
firefox, or Hyprland — the inverse of the desired survival order.

## Diagnosis (verified on the live system, 2026-06-12)

1. **tmux dies first because of ghostty + systemd-oomd.** `cz()` starts tmux
   from a shell inside ghostty, so the tmux server lives in
   `app-ghostty-surface-transient-*.scope`. Ghostty (`linux-cgroup=always`)
   hardcodes `ManagedOOMMemoryPressure=kill` on every surface scope
   (`src/apprt/gtk/cgroup.zig`, no config option to disable). Under global
   thrash the scope's PSI spikes, oomd kills inside it, the scope fails with
   `oom-kill`, and systemd tears down the whole cgroup — tmux server included.
   Observed 2026-06-12 11:20:30; five ghostty scopes currently `failed
   (oom-kill)`. This bypasses `systemd.oomd.enableUserSlices = false`, which
   only suppresses the global drop-ins, not per-unit properties.
2. **The freeze is a reclaim livelock, not an OOM.** Neither earlyoom nor the
   kernel OOM killer fired in 5 days. earlyoom needs mem ≤10% AND free swap
   ≤25% (>11.6G zram used); the box freezes around 10.7G — unreachable. The
   kernel never OOMs because reclaim keeps "succeeding" by evicting file cache
   that is immediately refaulted from NVMe.
3. **MGLRU is on but its anti-thrash knob is off.** `/sys/kernel/mm/lru_gen`
   enabled (0x0007), `min_ttl_ms = 0`.
4. **zram is less effective than it looks.** Effective compression after
   zsmalloc overhead ≈ 1.68:1; at 10.7G fill zram itself consumes ~6.4G RAM.
   There is no disk swap tier, so all anonymous memory stays resident.
5. **earlyoom's lists are stale.** Wrapped comm names (`.Hyprland-wrapp`,
   `.ghostty-wrappe`, `.waybar-wrapped`, `.Discord-wrappe`, `tmux: server`,
   `next-server (v1`) don't match the anchored regexes; `--prefer ^node$`
   targets claude's MCP servers; `-g` can group-kill claude with a node victim.
6. **node SIGABRT coredumps** (~300–500M heaps) are V8 failing OS page commits
   during thrash — a symptom of pressure, not an independent bug. `NODE_OPTIONS`
   is unset; Node's default heap cap (~4G) is not the cause.
7. `user.slice MemoryHigh=28G` on a 30G machine is effectively a no-op for
   protection and forces synchronous direct reclaim near the ceiling.

## Design

### Phase 1 — tmux/claude survive everything short of last resort

**1a. `agents.slice` + `tmux-main` user service** (`modules/system/memory.nix`
and `modules/hm/tmux.nix`):

- `systemd.user.slices."agents".sliceConfig.MemoryHigh = "22G"` — collective
  soft cap for the whole agent tree.
- NixOS-side `systemd.user.services.tmux-main`:
  - `Type=forking`, `ExecStart=zsh -lc 'exec tmux new-session -d -s main'` —
    the login shell provides the full NixOS PATH, resolving the historical
    objection recorded in memory.nix (service PATH too minimal for claude/node).
  - `Slice=agents.slice`, `OOMPolicy=continue` (a kernel-OOM kill of one child
    must not stop the unit), `Restart=on-failure`, `RestartSec=2`,
    `WantedBy=default.target`. Defined NixOS-side (static file under
    /etc/systemd/user) so rebuilds never restart it.
- tmux pane scopes (`tmux-spawn-*.scope`) inherit the server's slice (verified
  in tmux `compat/systemd.c`), so all claude panes move into `agents.slice`
  automatically.
- `cz()` becomes: start `tmux-main` via systemctl, then attach
  (`tmux new-session -A -s main` as fallback-attach). The interactive client
  may live in ghostty's scope; only the server placement matters.
- Recovery net: flip `@continuum-restore` to `on` so a genuinely killed server
  comes back with windows/panes/cwd restored; panes re-enter via
  `claude --resume`.

**1b. Neutralize ghostty's oomd opt-in** (`modules/hm/files.nix` or tmux.nix):
home-manager `xdg.configFile` ships
`~/.config/systemd/user/app-ghostty-surface-transient-.scope.d/50-no-oomd-kill.conf`:

```ini
[Scope]
ManagedOOMMemoryPressure=auto
```

Prefix drop-ins apply to transient units and are parsed after the transient
fragment, so `auto` wins over ghostty's `kill`. Keep `linux-cgroup=always`
(per-surface isolation remains useful). Verify after rebuild on a fresh
surface: `systemctl --user show 'app-ghostty-surface-transient-*.scope' -p
ManagedOOMMemoryPressure`.

**1c. Pane-scope hardening:** prefix drop-in
`tmux-spawn-.scope.d/50-agents.conf` with `OOMPolicy=continue` and
`MemoryHigh=12G` (per-pane soft cap, above observed claude peaks except the
13.9G outlier; one runaway pane gets reclaim-throttled instead of starving
siblings). Note pane scopes set `SendSIGHUP=yes`; `OOMPolicy=continue`
prevents a stray child OOM from SIGHUPing the whole pane.

**1d. earlyoom repair** (`modules/system/memory.nix`):

```nix
services.earlyoom = {
  enable = true;
  freeMemThreshold = 15;
  freeMemKillThreshold = 8;
  freeSwapThreshold = 50;      # fire near ~7.8G zram used, before the freeze
  freeSwapKillThreshold = 30;
  enableNotifications = true;
  reportInterval = 1800;
  extraArgs = [
    "--prefer" "^(\\.Discord-wrappe|Discord|firefox|Isolated Web Co|Web Content|next-server|esbuild|tsserver|jest|java|webpack|vite|turbo)"
    "--avoid"  "^(systemd|sshd|dbus|pipewire|wireplumber|claude|nvim|tmux: server|tmux: client|\\.ghostty-wrappe|\\.waybar-wrapped|\\.dunst-wrapped|hyprlock)$"
  ];
};
```

Decisions: drop `-g` (group kill can take claude down with a node MCP victim);
drop `^node$` from prefer (MCP servers are claude's organs); Hyprland stays
*neutral* — in earlyoom's flat ±300 prefer/avoid bands, putting Hyprland in
the avoid band would rank a 14G claude pane above it for killing. Neutral =
killed after preferred (discord/firefox/dev servers), before avoided
(claude/tmux). This preserves the desired order without Phase 2.

### Phase 3 — stop the daily freeze

**3a. MGLRU working-set protection** (`modules/system/memory.nix`):

```nix
systemd.tmpfiles.rules = [
  "w /sys/kernel/mm/lru_gen/min_ttl_ms - - - - 1000"
];
```

Never reclaim a working set younger than 1s; if impossible, trigger OOM kill
instead of livelocking. Converts the daily freeze into a single kill. The
kernel OOM pick is by oom_score (largest RSS) — typically the fattest claude
session, which is acceptable as true last resort: the tmux server (tiny)
survives, the pane is recoverable via `claude --resume`. If kills feel too
eager, lower to 500.

**3b. Disk swap tier** (`modules/system/memory.nix` or host config):

```nix
swapDevices = [ { device = "/swapfile"; size = 24 * 1024; priority = 10; } ];
boot.kernel.sysctl."vm.swappiness" = 100;  # was 130 (zram-only tuning)
```

zram (prio 100) stays the hot tier; truly cold anon pages (idle claude
sessions, background app heaps) age out to NVMe and release real RAM
(~0.6G per 1G moved, given the 1.68:1 effective zram ratio). NVMe wear is
negligible at this volume. zram sizing stays at 50%/zstd — growing it is
net-negative at the measured compression ratio.

**3c. Remove the no-op `user.slice MemoryHigh=28G`.** It cannot protect
anything at 28G/30G and adds direct-reclaim stalls near the ceiling. The
meaningful caps are now `app.slice` 20G (unchanged) and `agents.slice` 22G.
Update memory.nix's header comment to reflect the new strategy (oomd
neutralized at the ghostty source, agents in their own slice, MGLRU backstop).

### Phase 4 — claude "request resources and wait"

**4a. `memgate` PreToolUse hook.** Script (deployed via home-manager, e.g.
`~/.claude/hooks/memgate.sh`) gating subagent dispatch on real system state:

- Read `MemAvailable` (/proc/meminfo) and PSI `full avg10`
  (/proc/pressure/memory).
- Healthy (≥3G avail AND PSI <10) → exit 0 silently, normal flow.
- Under pressure → sleep-poll with 5–15s jitter (thundering-herd protection)
  up to 8 min; if it clears, allow; if not, emit
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny",
  "permissionDecisionReason":"System under sustained memory pressure — do not
  spawn subagents or heavy commands; continue with lightweight in-context work
  and retry later."}}`.
- Wait happens locally between API turns: zero tokens, no held connection.
  The deny-before-timeout matters because a hook that hits its timeout fails
  open.

`~/.claude/settings.json` registration (both accounts:
`~/.claude` and `~/.claude-account2`):

```json
{
  "env": { "NODE_OPTIONS": "--max-old-space-size=3072" },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Task|Agent",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/memgate.sh", "timeout": 540 }] },
      { "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/memgate.sh --quick", "timeout": 120 }] }
    ]
  }
}
```

`--quick` (Bash) variant: PSI threshold 25, max wait 90s — only blocks shell
commands when things are genuinely bad, since it fires on every command.
Caveat: if settings.json already exists with other content, merge rather than
overwrite (check during implementation whether it is hm-managed or mutable).

Rejected: token-bucket/broker daemon (PreToolUse process exits before the tool
runs, so it cannot hold a token for the subagent's lifetime; kernel PSI is
already the shared ground truth across all sessions). Rejected: SIGSTOP/freeze
governor (kept in back pocket only if freezes persist after Phases 1+3).

**4b. Per-session containment** is provided by 1c's per-pane
`MemoryHigh=12G` + the collective `agents.slice` 22G — no extra claude
wrapper needed. `memory.high` throttling makes an over-budget session wait at
the allocation site (the kernel-native version of "request and wait") while
the rest of the system stays responsive.

**4c. Node child hygiene:** `NODE_OPTIONS=--max-old-space-size=3072` (in 4a's
settings) bounds MCP-server heaps. The current SIGABRTs are expected to
disappear once Phases 1+3 keep MemAvailable above the floor.

## Error handling / failure modes

- oomd kill path: eliminated at the source (1b); even if something kills a
  ghostty scope, only that surface's client dies — `cz` reattaches.
- tmux server death (any cause): `Restart=on-failure` + continuum restore +
  `claude --resume` bound the damage.
- earlyoom now fires before the livelock; MGLRU OOM is the kernel backstop;
  both prefer non-agent victims (earlyoom by policy, MGLRU by RSS — usually a
  claude pane, the accepted last resort).
- memgate fails open on hook timeout by design; thresholds are tunable
  constants at the top of the script.

## Testing

1. After rebuild: `systemctl --user show` a fresh ghostty surface scope →
   `ManagedOOMMemoryPressure=auto`; `systemd-cgls` shows `tmux-main.service`
   and `tmux-spawn-*` scopes under `agents.slice`.
2. Kill test: `kill -9` the ghostty window hosting the attached client → tmux
   server and claude panes must survive; `cz` reattaches.
3. Pressure test (off-hours): run a memory hog (e.g. `stress-ng --vm`) and
   confirm order: earlyoom kills the hog/preferred victims, UI stays
   interactive, no livelock; `journalctl -u earlyoom` shows the kill.
4. memgate: with the hog running, ask a claude session to spawn a subagent →
   observe the wait, then release pressure → dispatch proceeds.
5. Watch `/proc/pressure/memory` full avg10 during a normal heavy day; tune
   memgate/earlyoom thresholds from observed values.

## Out of scope

- Phase 2 (chat/browser slices, graded oomd, firefox cgroup move) — dropped by
  user decision. Note: firefox still shares Hyprland's cgroup; a compositor
  kill triggered through that shared scope remains possible, accepted risk.
- nohang as earlyoom replacement — revisit only if freezes persist.

## Status

Implemented 2026-06-12 (see docs/superpowers/plans/2026-06-12-claude-session-stability.md).
Tuning expected: memgate thresholds (MEMGATE_*), earlyoom thresholds, MGLRU
min_ttl_ms (lower to 500 if kills feel eager) — revisit after a week of real load.
