# OOM Session-Resilience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `systemd-oomd` from SIGKILLing the entire Hyprland GUI session under memory pressure, and make running Claude agents survive any future session/compositor death.

**Architecture:** Three defense-in-depth layers on a 32 GB Dell XPS-13-9320 running NixOS + Hydenix + UWSM-managed Hyprland:
1. **Prevent** — contain the memory-hungry agent workload in a cgroup slice with `MemoryHigh` so the kernel throttles/reclaims *that slice* before the desktop starves; soften swap aggressiveness.
2. **Select** — disarm oomd's whole-cgroup swap-kill (which structurally targets the compositor's session scope) and let `earlyoom` (which protects `Hyprland`/`claude` and prefers `node`/`vite`) be the arbiter.
3. **Recover** — run the agents under a persistent multiplexer server pinned to a systemd *user service* + slice, so it survives ghostty/compositor death; reattach after re-login.

**Tech Stack:** NixOS modules (`systemd.oomd`, `systemd.slices`, `systemd.user.slices`, `systemd.user.services`, `services.earlyoom`, `zramSwap`, `boot.kernel.sysctl`), home-manager (`programs.tmux`), UWSM, cgroup v2.

---

## Review Findings & Revised Direction (2026-06-09, post 4-reviewer pass)

Four specialized reviewers (linux/cgroup, nix, network, sysadmin) verified against the live system. Verdicts: 1× GO, 3× GO-WITH-CHANGES. Convergent corrections:

1. **Topology premise was wrong** (see Key Constraints, corrected). Compositor + firefox share the uncapped logind `session-N.scope`; that co-residency is the real reason oomd kills the session. `app.slice` caps do not protect the compositor.
2. **Task 1 is unanimously THE incident fix** and the highest-value/lowest-risk change — ship it first, standalone. Cleanest form: `systemd.oomd.enableUserSlices = false` (one lever removes BOTH the swap-kill and the pressure-kill drop-ins across the user `user.slice`/`app.slice`/`session.slice`/`background.slice`), then drop the now-redundant `ManagedOOMSwap`/`ManagedOOMMemoryPressure` overrides. earlyoom becomes the sole selective killer. (nix reviewer confirmed `enableUserSlices=true` injects pressure-kill on the *user-manager* slices that the original Task 1 left armed — `enableUserSlices=false` closes that gap too.)
3. **`pkgs.tmux` is correct; `pkgs.userPkgs` does NOT exist** (CLAUDE.md is stale post-commit a60712b). Add `pkgs` to `memory.nix` signature. `useGlobalPkgs=true` means the service and HM share the same tmux derivation. `lib.mkForce`/option names all verified valid.
4. **Task 3 (tmux) has two real defects to fix before shipping:** (a) the `cz` `|| tmux new-session` fallback silently spawns an *uncontained* server outside `claude.slice` if the service is down — must be attach-only / fail-loud; (b) `Type=forking` without `PIDFile=` is fragile — verify cgroup placement is a hard gate. Also set **`programs.tmux.secureSocket = false`** or logout-survival silently depends on linger keeping `/run/user/1000` alive.
5. **Sysadmin KISS challenge:** the incident was an oomd swap-kill (Task 1 fixes it), not a logout — so Task 3's dedicated slice + custom service may be over-engineered. Minimal-viable subset = **Task 1 + Task 2**. Keep Task 3 only if cross-logout / compositor-crash persistence is a hard requirement (it has independent justification: ~15 historical Hyprland crash reports).
6. **Network (additive, GO):** sshd already runs in the **uncapped `system.slice`**, so it survives the OOM event → remote SSH reattach already works on-LAN today and is a *more* reliable recovery path than local re-login. Optional multipliers: `services.tailscale.enable` (off-LAN/phone, NAT traversal), `programs.mosh.enable` (roaming links), and key-only SSH hardening (currently `PasswordAuthentication yes` on `0.0.0.0:22`).
7. **Structural root issue (new):** firefox sharing the compositor's session scope is *why* the desktop is the OOM target. The durable fix is to either make UWSM actually effective (apps→`app.slice`, compositor→`session.slice`) or launch firefox into its own app scope — separate investigation, flagged not bundled.

**Revised tiering:** Task 1 (`enableUserSlices=false`) → ship now. Task 2 (swappiness + `claude.slice`/`app.slice` soft caps, honestly scoped to "contain agents") → cheap. Task 3 (tmux, fixed defects, simplified) → only if persistence wanted. Tier 4 (remote reattach) → optional. UWSM/firefox → separate.

## Implementation Note (2026-06-09, Stage A revised after a runtime bug)

First Stage-A attempt used a `systemd.user.services.claude-tmux` server pinned to a dedicated `claude.slice`. On apply, every shell inside the resulting tmux session had a **gutted PATH** (`coreutils:findutils:gnugrep:gnused:systemd` — systemd's minimal service default): `claude` (`~/.local/bin`), `carapace`/`zoxide` (`/run/current-system/sw/bin`), `fastfetch` (`/etc/profiles/per-user/dori/bin`) all became "command not found". Confirmed via `/proc/<pane-pid>/environ`. Root cause: **a tmux server launched by a systemd user service does not inherit the rich user-session PATH** — far worse than the "stale env" the reviewers flagged.

**Revised Task 3 (shipped):** dropped the service AND the dedicated `claude.slice`. `cz` now starts a plain tmux server from the interactive login shell (`tmux new-session -A -s main`), so it inherits the full environment; containment comes from the `app.slice` soft cap; persistence from tmux daemonization + existing linger. Simpler, no env bug — matches the sysadmin reviewer's minimal-viable recommendation. The cross-logout survival test remains the acceptance gate.

## Stage B (UWSM switch) — investigated, deliberately SKIPPED (2026-06-09)

Root cause of UWSM being inert: Hydenix hardcodes `services.displayManager.sddm.settings.General.DefaultSession = "hyprland.desktop"` (`hydenix/modules/system/sddm.nix`); `hydenix.hm.uwsm.enable` only drops `~/.config/uwsm/` env files, it never selects the uwsm session. The switch would be `lib.mkForce "hyprland-uwsm.desktop"` on that attribute.

Decision: **not done.** Stage A already removed the kill path that caused the logout, and the agents are already in `app.slice` (ghostty self-places, independent of UWSM). Stage B's only incremental gain is containing **firefox**, and even the session switch wouldn't deliver it — the unwrapped `exec-once = ... firefox` inherits the compositor's cgroup; realizing the cap requires `exec-once = ... uwsm app -- firefox`. Marginal benefit + relogin/session-launch risk → skipped. Revisit only if firefox memory becomes a concrete problem. Acceptance gate if ever resumed: `cat /proc/$(pgrep -x firefox|head -1)/cgroup` must show `app.slice`.

## Incident Recap (root cause — already established)

```
Jun 09 14:29:41  systemd-oomd[1008]: Killed /user.slice/user-1000.slice/session-3.scope
  due to memory used (30.3G/33.2G) and swap used (14.9G/16.6G) being more than 90.00%
```

- Machine never rebooted (session-level kill, no coredump).
- `modules/system/memory.nix:43` left `ManagedOOMSwap = "kill"` armed. oomd kills the descendant cgroup with the most swap; because UWSM fragments apps across many per-surface `app-*.scope` cgroups, the single fattest cgroup was `session-3.scope` (the compositor's home) → whole GUI session SIGKILLed.
- Agents themselves live in `user@1000.service/app.slice/app-ghostty-surface-transient-*.scope` (NOT the killed scope). They died as a **cascade**: Hyprland died → ghostty lost its Wayland socket → claude PTYs got SIGHUP.
- `Linger=yes` and `KillUserProcesses=false` are already set.

## Key Constraints / Environment Facts

- **UWSM is enabled in config (`hydenix.hm.uwsm.enable = true`) but NOT effective at runtime** (verified by all reviewers): no `uwsm`/`wayland-wm@` process exists; SDDM launches `start-hyprland` directly. Consequence: **Hyprland, firefox (+~45 web-content procs), Xwayland, fcitx5 all live in the logind `session-N.scope`** (~11 G, uncapped), a *sibling* of `user@1000.service`. The **agents** (ghostty/claude/node/next-dev/firebase) live in `user@1000.service/app.slice/app-ghostty-surface-transient-*.scope`. So `app.slice` caps contain the agents but do NOT protect the compositor. Slice tuning targets the **user** manager via `systemd.user.slices`; the system-level `user.slice` via `systemd.slices`.
- Swap = `zram0`, 15.5 G, zstd, priority 100 (lives in RAM).
- Shell = zsh; user config is sourced from `~/.zsh_dori` ← `modules/hm/home/zshrc`.
- System modules imported in `modules/system/default.nix`; `memory.nix` already imported there.
- HM config lives in `modules/hm/default.nix` (alongside `programs.direnv`, `programs.neovim`).
- Host config: `host/config.nix`. Build: `sudo nixos-rebuild test --flake .#xps13-9320` (Adrien runs sudo).

## Files Touched

- Modify: `modules/system/memory.nix` — Layer 1 (slice caps, swappiness) + Layer 2 (oomd swap-kill) + Layer 3 service/slice for the multiplexer.
- Modify: `modules/hm/default.nix` — `programs.tmux` enablement.
- Modify: `modules/hm/home/zshrc` — `cz` attach helper.

> Layer 3's systemd **user** service is declared at the system level via `systemd.user.services` in `memory.nix` (system manager defines user units globally), keeping all OOM/resilience wiring in one file. Alternative placement (home-manager `systemd.user.services`) noted in Decisions.

---

## Decisions & Open Questions (PRIMARY FOCUS FOR REVIEWERS)

These forks are deliberately left for review. The plan below implements the **recommended** choice for each; reviewers should confirm or redirect.

- **D1 — Multiplexer: tmux (recommended) vs zellij.** tmux's detached-server model (`tmux new-session -d`) maps cleanly onto a `systemd --user` oneshot service with no attached client, giving a stable, slice-pinned, persistent server. zellij has nicer UX + `programs.zellij` HM module + session serialization, but its client-driven daemon is awkward to run as a headless service. **Recommended: tmux**, for robust service-managed persistence.
- **D2 — Containment granularity: dedicated `claude.slice` (recommended) vs cap the whole `app.slice`.** Dedicated slice = surgical (only agents throttled), and the tmux server is pinned into it. Capping `app.slice` = simpler, no wrapper, but throttles all GUI apps together (firefox/discord share the budget). **Recommended: dedicated `claude.slice`** for the tmux server + a *generous soft* `MemoryHigh` on `app.slice` as a backstop.
- **D3 — `MemoryHigh` values.** Proposed: `claude.slice` = 18 G (throttle agents), `app.slice` = 24 G (loose backstop), system `user.slice` stays 28 G. Total RAM 32 G. Reviewers (sysadmin/linux) to sanity-check headroom for kernel + `system.slice` (pipewire, etc.) + compositor.
- **D4 — `vm.swappiness`.** 180 → 130 proposed. zram guidance often favors high swappiness; reviewers to weigh 130 vs keeping higher.
- **D5 — Does the tmux server inheriting service-start env (stale `WAYLAND_DISPLAY`) matter?** For CLI agents + node dev-servers: expected no. Confirm.
- **D6 — Workflow change:** agents must be started inside the tmux session (`cz`) to gain protection. Acceptable?

---

## Task 1: Layer 2 — Disarm oomd's session-killing swap path

This is the **direct fix for the observed incident** and the lowest-risk change. Do it first and independently.

**Files:**
- Modify: `modules/system/memory.nix:41-49`

- [ ] **Step 1: Edit the user slice `sliceConfig`**

Replace the `ManagedOOMSwap = "kill"` line and refresh the comment:

```nix
  systemd.slices."user".sliceConfig = {
    MemoryHigh = "28G";
    # 2026-06-09: oomd's swap-kill SIGKILLed the whole GUI session (session-3.scope)
    # because UWSM fragments apps across per-surface scopes, making the compositor's
    # session scope the single fattest cgroup. Both oomd kill paths (swap AND pressure)
    # ignore earlyoom's --prefer/--avoid, so we disable BOTH and let earlyoom — which
    # protects Hyprland/claude and prefers node/vite — be the sole selective killer.
    ManagedOOMSwap = lib.mkForce "auto";
    ManagedOOMMemoryPressure = lib.mkForce "auto";
  };
```

- [ ] **Step 2: Dry-build to verify evaluation**

Run: `nixos-rebuild dry-build --flake .#xps13-9320`
Expected: builds with no eval error.

- [ ] **Step 3: Apply (user runs sudo) and verify oomd no longer manages the user slice for kills**

Run: `sudo nixos-rebuild test --flake .#xps13-9320`
Then: `systemctl show user-1000.slice | grep -i ManagedOOM`
Expected: `ManagedOOMSwap=auto` and `ManagedOOMMemoryPressure=auto`.

- [ ] **Step 4: Commit**

```bash
git add modules/system/memory.nix
git commit -m "fix: stop oomd swap-kill from nuking the GUI session"
```

---

## Task 2: Layer 1 — Soften swap + add app.slice backstop cap

**Files:**
- Modify: `modules/system/memory.nix` (`boot.kernel.sysctl`, add `systemd.user.slices`)

- [ ] **Step 1: Lower swappiness**

Change `boot.kernel.sysctl."vm.swappiness"` from `180` to `130`.

- [ ] **Step 2: Add a loose MemoryHigh backstop on the user-manager app.slice**

Add to `memory.nix` (the user systemd manager, where UWSM places GUI apps):

```nix
  # User-manager app.slice holds all GUI apps (ghostty, browsers, agents).
  # A loose MemoryHigh makes the kernel reclaim/throttle the app group before it
  # can starve the compositor (which runs outside app.slice). Soft limit: no kills.
  systemd.user.slices."app".sliceConfig.MemoryHigh = "24G";
```

- [ ] **Step 3: Dry-build**

Run: `nixos-rebuild dry-build --flake .#xps13-9320`
Expected: no eval error.

- [ ] **Step 4: Apply and verify**

Run: `sudo nixos-rebuild test --flake .#xps13-9320`
Then: `systemctl --user show app.slice | grep -i MemoryHigh` and `cat /proc/sys/vm/swappiness`
Expected: `MemoryHigh=25769803776` (24 G) and `130`.

- [ ] **Step 5: Commit**

```bash
git add modules/system/memory.nix
git commit -m "feat: soften swappiness, add app.slice memory backstop"
```

---

## Task 3: Layer 1+3 — Dedicated claude.slice + persistent tmux user service

**Files:**
- Modify: `modules/system/memory.nix` (add `systemd.user.slices.claude` + `systemd.user.services.claude-tmux`)
- Modify: `modules/hm/default.nix` (enable `programs.tmux`)
- Modify: `modules/hm/home/zshrc` (add `cz` helper)

- [ ] **Step 1: Declare the contained slice + persistent tmux server (system module)**

Add to `modules/system/memory.nix`:

```nix
  # Surgical containment for the agent workload: tmux server + every process it
  # spawns (claude, node, vite, firebase emulators) lives here and is throttled
  # as a group, protecting the compositor and the rest of the desktop.
  systemd.user.slices."claude".sliceConfig.MemoryHigh = "18G";

  # Detached tmux server, pinned into claude.slice, started by the user manager.
  # Survives ghostty/compositor death and logout (Linger=yes is already set), so
  # agents started inside it persist across a forced re-login.
  systemd.user.services."claude-tmux" = {
    description = "Persistent tmux server for Claude agent sessions";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "forking";
      Slice = "claude.slice";
      ExecStart = "${pkgs.tmux}/bin/tmux new-session -d -s main";
      ExecStop = "${pkgs.tmux}/bin/tmux kill-server";
      Restart = "on-failure";
      # Last-resort: if this slice blows past the soft limit, OOM-kill happens
      # INSIDE claude.slice (an agent), never the compositor.
      OOMPolicy = "continue";
    };
  };
```

> Note: `pkgs` must be in scope in `memory.nix`. Current signature is `{ lib, ... }:` — add `pkgs`. Reviewers (nix) confirm `pkgs.tmux` is the right ref vs `pkgs.userPkgs.tmux`.

- [ ] **Step 2: Enable tmux in home-manager**

Add to `modules/hm/default.nix` near `programs.direnv`:

```nix
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    escapeTime = 10;
    historyLimit = 50000;
    mouse = true;
  };
```

- [ ] **Step 3: Add the attach helper to zsh**

Append to `modules/hm/home/zshrc`:

```sh
# Attach to the persistent, memory-contained agent session (Layer 3).
# The server runs as a user service in claude.slice and survives logout/compositor crashes.
cz() { tmux attach -t main 2>/dev/null || tmux new-session -s main; }
```

- [ ] **Step 4: Dry-build**

Run: `nixos-rebuild dry-build --flake .#xps13-9320`
Expected: no eval error; `pkgs` resolves in `memory.nix`.

- [ ] **Step 5: Apply, then verify slice placement at runtime**

Run: `sudo nixos-rebuild test --flake .#xps13-9320` then `home-manager switch --flake .#hm` (or rebuild covers HM).
Then start work via `cz`, launch a claude agent in it, and verify it landed in the slice:

```bash
systemctl --user status claude-tmux
systemd-cgls --user-unit claude.slice
# claude + tmux: server PID should appear under claude.slice
cat /proc/$(pgrep -n -f 'tmux: server')/cgroup   # expect .../claude.slice
systemctl --user show claude.slice | grep -i MemoryHigh   # expect 18G
```

Expected: tmux server and the claude/node children resolve to `.../claude.slice`.

- [ ] **Step 6: Survival test (the actual acceptance criterion)**

With a claude agent running inside `cz`:
1. `loginctl terminate-session <current-graphical-session>` (or hard-test: kill the compositor).
2. Re-login via SDDM.
3. `cz` → confirm the agent is still running and reattaches.

Expected: agent process PID unchanged across the re-login.

- [ ] **Step 7: Commit**

```bash
git add modules/system/memory.nix modules/hm/default.nix modules/hm/home/zshrc
git commit -m "feat: persistent slice-contained tmux server for agent resilience"
```

---

## Task 4: Optional — earlyoom acts before any backstop

**Files:**
- Modify: `modules/system/memory.nix:16-29` (`services.earlyoom`)

- [ ] **Step 1: Widen swap thresholds so earlyoom selectively kills a build tool with headroom to spare**

```nix
    freeSwapThreshold = 25;       # was 20: act earlier
    freeSwapKillThreshold = 15;   # was 10: SIGKILL a node/vite before swap is critical
```

- [ ] **Step 2: Dry-build, apply, verify**

Run: `nixos-rebuild dry-build --flake .#xps13-9320` then `sudo nixos-rebuild test ...`
Then: `systemctl show earlyoom.service | grep ExecStart` and confirm `-s 25,15`.

- [ ] **Step 3: Commit**

```bash
git add modules/system/memory.nix
git commit -m "tune: earlyoom acts earlier on swap pressure"
```

---

## Rollback

All changes are declarative. `sudo nixos-rebuild test` does NOT persist across reboot — if anything misbehaves, reboot returns to the previous generation. To revert a switched generation: `sudo nixos-rebuild switch --rollback` or select the prior generation in systemd-boot. `git revert` the relevant commit and rebuild.

## Self-Review Notes

- Spec coverage: Layer 1 = Tasks 2+3 (slice caps + swappiness); Layer 2 = Task 1 (oomd); Layer 3 = Task 3 (tmux service). Task 4 is optional tuning.
- Verified via MCP: `systemd.user.slices` and `programs.zellij`/`programs.tmux` options exist.
- Unverified assumptions flagged inline for reviewers: `pkgs` scope in memory.nix, UWSM/app.slice interaction, tmux-server cgroup inheritance under a forking user service, exact MemoryHigh headroom.
