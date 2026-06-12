# Claude Session Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make tmux + Claude Code sessions survive memory pressure (killed only as last resort), eliminate the daily reclaim-livelock freeze, and gate Claude's subagent/command dispatch on actual CPU/RAM availability.

**Architecture:** Three layers per the approved spec (`docs/superpowers/specs/2026-06-12-claude-session-stability-design.md`): (1) move the tmux server into a dedicated `agents.slice` user service and neutralize ghostty's hardcoded oomd kill property with systemd prefix drop-ins; (2) repair earlyoom's dead regexes/thresholds, enable MGLRU `min_ttl_ms`, and add a low-priority NVMe swap tier; (3) a `memgate` PreToolUse hook that makes Claude wait for resources before spawning subagents.

**Tech Stack:** NixOS (flake `.#xps13-9320`), home-manager (integrated as NixOS module), systemd user units + prefix drop-ins, earlyoom, MGLRU, bash hook script, Claude Code hooks API.

**Key context for a zero-context engineer:**
- This repo is a NixOS flake config. System modules live in `modules/system/` (imported via `modules/system/default.nix`), home-manager modules in `modules/hm/` (imported via `modules/hm/default.nix`). 2-space indent.
- `nixos-rebuild` requires sudo. The user must run sudo commands themselves — the agent asks; everything else the agent runs.
- The tmux server is CURRENTLY RUNNING inside a ghostty surface scope hosting live claude sessions. Migration to the new service requires a deliberate server restart (Task 6) — do not kill it as a side effect.
- `~/.claude/settings.json` and `~/.claude-account2/settings.json` are live, hand-managed files NOT in this repo. Merge into them with jq; never overwrite blindly.
- Verify Nix changes with a sudo-less full build: `nix build .#nixosConfigurations.xps13-9320.config.system.build.toplevel --no-link` (slow first time, cached after).

---

### Task 1: Rewrite `modules/system/memory.nix` (agents.slice, tmux-main service, earlyoom repair, MGLRU, swapfile)

**Files:**
- Modify: `modules/system/memory.nix` (full rewrite below)

- [ ] **Step 1: Replace the entire content of `modules/system/memory.nix` with:**

```nix
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
      ExecStart = "${pkgs.zsh}/bin/zsh -lc 'exec tmux new-session -d -s main'";
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "agents.slice";
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
```

- [ ] **Step 2: Verify the system evaluates and builds**

Run: `nix build .#nixosConfigurations.xps13-9320.config.system.build.toplevel --no-link`
Expected: completes with no error (warnings OK). If it fails on `swapDevices` merge, the empty `swapDevices = [ ];` in `host/hardware-configuration.nix` is NOT the cause (lists merge by concatenation) — read the actual error.

- [ ] **Step 3: Commit**

```bash
git add modules/system/memory.nix
git commit -m "feat(memory): agents.slice + tmux-main service, earlyoom repair, MGLRU backstop, disk swap tier"
```

---

### Task 2: systemd prefix drop-ins + continuum restore in `modules/hm/tmux.nix`

**Files:**
- Modify: `modules/hm/tmux.nix`

- [ ] **Step 1: Update the header comment (lines 9-11)**

Replace:

```nix
  # Persistent multiplexer for Claude agent sessions (see modules/system/memory.nix).
  # secureSocket=false puts the socket in /tmp so the server outlives the /run/user
  # lifetime; with linger enabled the `cz` session survives a forced logout.
```

with:

```nix
  # Persistent multiplexer for Claude agent sessions. The server runs as the
  # tmux-main user service in agents.slice (modules/system/memory.nix) so no
  # ghostty/compositor scope death can reach it; the drop-ins below neutralize
  # ghostty's hardcoded oomd kill property and harden the per-pane scopes.
  # secureSocket=false puts the socket in /tmp so the server outlives the
  # /run/user lifetime; with linger enabled it survives a forced logout.
```

- [ ] **Step 2: Flip continuum restore on (recovery net for a genuinely killed server)**

In the `continuum` plugin block, replace:

```nix
          set -g @continuum-restore 'off'
```

with:

```nix
          set -g @continuum-restore 'on'
```

- [ ] **Step 3: Add the systemd user drop-ins**

Add after the closing of `programs.tmux = { ... };` (before the final `}` of the file):

```nix
  # ghostty (linux-cgroup=always) hardcodes ManagedOOMMemoryPressure=kill on
  # every app-ghostty-surface-transient-*.scope (src/apprt/gtk/cgroup.zig; no
  # config option). Under global thrash, oomd then kills inside the surface
  # scope and systemd tears the whole cgroup down — this is what used to take
  # the tmux server (and every claude session) with it. Prefix drop-ins apply
  # to transient units and are parsed after the transient fragment, so this
  # override wins. linux-cgroup=always itself stays: per-surface isolation is
  # useful once tmux is out of the blast radius.
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
```

- [ ] **Step 4: Verify build**

Run: `nix build .#nixosConfigurations.xps13-9320.config.system.build.toplevel --no-link`
Expected: success.

- [ ] **Step 5: Commit**

```bash
git add modules/hm/tmux.nix
git commit -m "feat(tmux): neutralize ghostty oomd kill, harden pane scopes, enable continuum restore"
```

---

### Task 3: New `cz()` in `modules/hm/home/zshrc`

**Files:**
- Modify: `modules/hm/home/zshrc:32-36`

- [ ] **Step 1: Replace the cz block**

Replace (lines 32-36):

```zsh
# Attach to (or create) the persistent agent tmux session. Started from this real
# login shell, so it inherits the full PATH/env; it lives under app.slice (soft
# memory cap) and, with linger enabled, survives a forced logout / compositor crash —
# reattach with `cz` after re-login.
cz() { tmux new-session -A -s main; }
```

with:

```zsh
# Attach to (or create) the persistent agent tmux session. The server runs as
# the tmux-main user service in agents.slice (modules/system/memory.nix), out
# of reach of ghostty/compositor scope deaths — reattach with `cz` after any
# crash or re-login. If the service is unavailable, -A falls back to creating
# the session in-place (old behavior).
cz() {
  systemctl --user start tmux-main 2>/dev/null
  tmux new-session -A -s main
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/hm/home/zshrc
git commit -m "feat(zsh): cz starts tmux via the tmux-main service"
```

---

### Task 4: memgate hook script

**Files:**
- Create: `modules/hm/scripts/memgate.sh`
- Modify: `modules/hm/files.nix` (add deploy entry)

- [ ] **Step 1: Create `modules/hm/scripts/memgate.sh`**

```bash
#!/usr/bin/env bash
# Claude Code PreToolUse admission gate: block new subagents (and, with
# --quick, heavy Bash commands) while the system is under memory pressure.
# Waits (sleep-poll, zero tokens, no held API connection) until resources
# free up; past MAX_WAIT it denies with guidance so the hook never trips its
# own timeout (a timed-out hook fails OPEN and the tool runs anyway).
# Registered in ~/.claude/settings.json and ~/.claude-account2/settings.json.
# Thresholds are env-overridable for testing (MEMGATE_*).
set -u

QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

MIN_AVAIL_GB="${MEMGATE_MIN_AVAIL_GB:-3}"
MAX_PSI="${MEMGATE_MAX_PSI:-10}"   # /proc/pressure/memory "full avg10" ceiling (%)
MAX_WAIT="${MEMGATE_MAX_WAIT:-480}" # seconds; must stay below the hook timeout
if [ "$QUICK" = 1 ]; then
  MAX_PSI="${MEMGATE_MAX_PSI:-25}"
  MAX_WAIT="${MEMGATE_MAX_WAIT:-90}"
fi

healthy() {
  local avail psi
  avail=$(awk '/MemAvailable/{print int($2/1048576)}' /proc/meminfo)
  psi=$(awk '/^full/{sub("avg10=","",$2); print int($2)}' /proc/pressure/memory)
  [ "$avail" -ge "$MIN_AVAIL_GB" ] && [ "$psi" -lt "$MAX_PSI" ]
}

waited=0
until healthy; do
  if [ "$waited" -ge "$MAX_WAIT" ]; then
    cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"System under sustained memory pressure: do not spawn subagents or heavy commands right now. Continue with lightweight in-context work and retry later."}}
EOF
    exit 0
  fi
  # 5-15s jitter: avoids a thundering herd when several sessions' hooks wake
  # together as pressure clears.
  s=$((5 + RANDOM % 10))
  sleep "$s"
  waited=$((waited + s))
done
exit 0
```

- [ ] **Step 2: Test the script directly (before any deploy)**

```bash
chmod +x modules/hm/scripts/memgate.sh
# Healthy path: must exit 0 silently
./modules/hm/scripts/memgate.sh; echo "exit=$?"
# Pressure path: force an unreachable threshold, short wait -> deny JSON
MEMGATE_MIN_AVAIL_GB=999 MEMGATE_MAX_WAIT=5 ./modules/hm/scripts/memgate.sh; echo "exit=$?"
```

Expected: first run prints only `exit=0` (within ~1s). Second run sleeps 5-15s, prints the one-line deny JSON, then `exit=0`.

- [ ] **Step 3: Deploy via `modules/hm/files.nix`**

Add inside `home.file = { ... }`, next to the other script entries (after the `claude-statusline.sh` block):

```nix
    ".claude/hooks/memgate.sh" = {
      source = ./scripts/memgate.sh;
      force = true;
      mutable = true;
      executable = true;
    };
```

- [ ] **Step 4: Verify build**

Run: `nix build .#nixosConfigurations.xps13-9320.config.system.build.toplevel --no-link`
Expected: success.

- [ ] **Step 5: Commit**

```bash
git add modules/hm/scripts/memgate.sh modules/hm/files.nix
git commit -m "feat(claude): memgate PreToolUse hook gating dispatch on memory pressure"
```

---

### Task 5: Register hooks + NODE_OPTIONS in both Claude settings files (imperative, not in repo)

**Files:**
- Modify (live, NOT in git): `~/.claude/settings.json`, `~/.claude-account2/settings.json`

These are hand-managed files with existing content (permissions, statusline, plugins...). MERGE with jq; keep `.bak` backups. The hook command path is absolute and shared by both accounts.

- [ ] **Step 1: Merge env + hooks into both settings files**

```bash
for f in ~/.claude/settings.json ~/.claude-account2/settings.json; do
  cp "$f" "$f.bak"
  jq '.env.NODE_OPTIONS = "--max-old-space-size=3072"
      | .hooks.PreToolUse = [
          {matcher: "Task|Agent",
           hooks: [{type: "command", command: "/home/dori/.claude/hooks/memgate.sh", timeout: 540}]},
          {matcher: "Bash",
           hooks: [{type: "command", command: "/home/dori/.claude/hooks/memgate.sh --quick", timeout: 120}]}
        ]' "$f.bak" > "$f"
done
```

- [ ] **Step 2: Verify both files are valid JSON and contain the hooks**

```bash
for f in ~/.claude/settings.json ~/.claude-account2/settings.json; do
  jq -e '.hooks.PreToolUse | length == 2' "$f" && jq -e '.env.NODE_OPTIONS' "$f"
done
```

Expected: prints `true` and `"--max-old-space-size=3072"` for each file. If jq errors, restore from `.bak` and merge by hand.

NOTE: `~/.claude/hooks/memgate.sh` only exists after Task 6's rebuild deploys it. Hooks on a missing script fail open (non-blocking) — acceptable in the gap, but Task 6 must verify the file landed. Existing claude sessions pick hooks up on their next session start, not live.

No commit (files are outside the repo).

---

### Task 6: Rebuild, migrate the live tmux server, verify everything

**Files:** none (operations only)

- [ ] **Step 1: Ask the user to run the rebuild (sudo required — agent must not run this)**

Ask the user to execute:

```bash
sudo nixos-rebuild test --flake .#xps13-9320
```

Expected: activation succeeds; a `/swapfile` (24G) is allocated and swapped on (first activation takes a minute). If all is well, the user runs `sudo nixos-rebuild switch --flake .#xps13-9320` to make it boot-persistent.

- [ ] **Step 2: Verify system-level knobs (agent runs these)**

```bash
cat /sys/kernel/mm/lru_gen/min_ttl_ms          # expected: 1000
swapon --show                                   # expected: zram0 prio 100 AND /swapfile prio 10
sysctl vm.swappiness                            # expected: 100
systemctl cat --user tmux-main                  # expected: unit exists, Slice=agents.slice
grep -c "prefer" /proc/$(pgrep -x earlyoom)/cmdline 2>/dev/null || systemctl show earlyoom -p ExecStart | tr '\0' ' ' | grep -o 'Discord-wrappe'  # expected: new regex active
ls -l ~/.claude/hooks/memgate.sh                # expected: present, executable
systemctl --user daemon-reload                  # make sure drop-ins are loaded for future scopes
```

- [ ] **Step 3: Verify the ghostty drop-in on a FRESH surface**

Ask the user to open a new ghostty window/tab, then:

```bash
systemctl --user show "$(systemctl --user list-units --no-legend 'app-ghostty-surface-transient-*' | tail -1 | awk '{print $1}')" -p ManagedOOMMemoryPressure
```

Expected: `ManagedOOMMemoryPressure=auto`. (Old surfaces created before the rebuild still say `kill` — only new ones matter.)

- [ ] **Step 4: Migrate the live tmux server (coordinate with the user — kills current panes!)**

The running server still lives in the old ghostty scope; a server restart is required exactly once. Ask the user to pick a moment (claude sessions will need `claude --resume` afterwards), then run:

```bash
tmux kill-server 2>/dev/null
systemctl --user start tmux-main
systemctl --user status tmux-main --no-pager   # expected: active (running)
systemd-cgls --user-unit tmux-main.service --no-pager | head -5  # expected: under agents.slice
cz   # attaches; continuum restores windows/panes/cwd; claude --resume per pane
```

- [ ] **Step 5: Survival test (the actual acceptance test for the headline bug)**

With `cz` attached inside ghostty, ask the user to force-close that ghostty window (or `kill -9` the ghostty surface pid). Then in another terminal:

```bash
systemctl --user is-active tmux-main   # expected: active
tmux ls                                # expected: main session still listed
```

Reattach with `cz`. PASS = server and panes survived the terminal death.

- [ ] **Step 6: memgate end-to-end check (cheap version, no real pressure needed)**

In a NEW claude session (hooks load at session start), confirm a trivial Bash tool call works (gate is open when healthy). Then simulate pressure by temporarily editing the deployed copy's threshold:

```bash
MEMGATE_MIN_AVAIL_GB=999 MEMGATE_MAX_WAIT=5 ~/.claude/hooks/memgate.sh; echo $?
```

Expected: deny JSON after ~5-15s, exit 0 (same as Task 4 — this confirms the deployed copy). Real-pressure behavior (waiting, then allowing) is validated passively over the next heavy day by watching `journalctl -u earlyoom -f` and `/proc/pressure/memory`.

- [ ] **Step 7: Update the spec status and commit**

Append to the bottom of `docs/superpowers/specs/2026-06-12-claude-session-stability-design.md`:

```markdown

## Status

Implemented 2026-06-12 (see docs/superpowers/plans/2026-06-12-claude-session-stability.md).
Tuning expected: memgate thresholds (MEMGATE_*), earlyoom thresholds, MGLRU
min_ttl_ms (lower to 500 if kills feel eager) — revisit after a week of real load.
```

```bash
git add docs/superpowers/specs/2026-06-12-claude-session-stability-design.md
git commit -m "docs: mark stability spec implemented"
```

---

## Self-review notes

- Spec coverage: 1a (Task 1 service+slice, Task 3 cz), 1b (Task 2 ghostty drop-in), 1c (Task 2 pane drop-in), 1d (Task 1 earlyoom), 3a/3b/3c (Task 1 tmpfiles/swapfile/sysctl/slice removal + comments), 4a (Tasks 4+5), 4b (covered by 1c+agents.slice, no extra work), 4c (Task 5 NODE_OPTIONS). Continuum restore (1a recovery net) in Task 2.
- Known risks called out in-plan: live-server migration (Task 6 Step 4), hooks-fail-open gap between Task 5 and Task 6, old surfaces keeping the kill property.
