# Ghostty: new window opens but the shell never appears

Investigation 2026-08-19. **Root cause found and confirmed by direct measurement.**

## Summary

The user account is pinned at its `RLIMIT_MEMLOCK` ceiling (8 MiB, the systemd default) by
**280 io_uring rings across 93 processes** — 272 of them held by node/npm processes, i.e. Claude
Code and its MCP servers. New ring allocation for uid 1000 currently fails outright.

Ghostty's event loop (libxev) needs a **new io_uring ring per surface**. When a new window is
opened, the ring allocation fails, `initSurface()` returns `error.SystemResources`, and ghostty
**swallows the error with a `log.warn`** — which goes to `/dev/null`. The result is a mapped,
painted, permanently blank window with no pty, no shell, and no error anywhere.

Upstream, untriaged, no fix released:
[ghostty-org/ghostty#12988](https://github.com/ghostty-org/ghostty/discussions/12988) — same
version (1.3.1), same distro (NixOS), same compositor (Wayland), title stuck at `Ghostty`, traced
to this exact mechanism.

## Why it hits the long-lived instance and not a fresh one

libxev chooses its backend **once, at process start**, and falls back to epoll if io_uring is
unavailable. That fallback does not exist per-surface.

- `ghostty` PID 2998071 started **Aug 17 20:22**, when rings were still available. It committed to
  the io_uring backend and holds 6 rings. Every new surface needs another ring — and can no longer
  get one. **No fallback. It fails.**
- A ghostty started **today** finds the account already at the cap, falls back to epoll at startup,
  and works perfectly forever.

This was verified directly, not inferred:

| probe | memlock | io_uring fds | shell started |
|---|---|---|---|
| fresh ghostty, default limit | 8 MiB | **0** | yes (epoll fallback) |
| fresh ghostty, `ulimit -l 64` | 64 KiB | **0** | yes (epoll fallback) |
| PID 2998071 (started Aug 17) | 8 MiB | **6** | — |

A fresh ghostty getting **zero** rings at the *default* limit is the direct proof that the account
is currently unable to allocate any new ring at all.

## Hard timing evidence

`linux-cgroup=always` makes every successful surface register a systemd scope named after its
shell PID, so the journal is an exact log of surface spawns:

```
Aug 17 20:22:39  Started app-ghostty-surface-transient-2998105.scope   <- tmux surface
Aug 17 20:22:42  Started app-ghostty-surface-transient-2998530.scope   <- mosh surface
        ... 44 hours, zero scopes ...
Aug 19 16:04:07  Started app-ghostty-surface-transient-975197.scope    <- recovered
```

**Not one surface spawned a shell between Aug 17 20:22:42 and Aug 19 16:04:07.** The failure was
persistent for the entire window, not intermittent — it tracks how long node/MCP ring pressure was
held, and it survived a suspend/resume cycle (Aug 19 01:33 → 09:28) untouched.

## Corroborating fingerprint

During a stall, ghostty carried orphaned `ghostt:traceq0` / `ghostty:gdrv0` (Mesa) thread pairs
with **no matching `renderer` / `io` / `io-reader` threads** — exactly **+4 threads per failed
attempt**, independently matching
[#13554](https://github.com/ghostty-org/ghostty/issues/13554) (1.3.1, `--gtk-single-instance=true`,
~3 days uptime, no new shell, no new transient scope). They are reaped later.

Note: the `2998082/83` + `2998084/85` pair-group is startup GL probing, not an orphan.

## The measurement

```
RLIMIT_MEMLOCK           8388608 bytes (8 MiB, systemd default)
account-wide io_uring rings                280  across 93 processes
  node                                     123
  npm exec <mcp-server> (×10 servers)      ~132
  ghostty                                    6
```

**What proves the account is at the cap is the probe, not arithmetic.** A fresh ghostty launched
today under the *default* 8 MiB limit obtained **zero** io_uring rings and silently fell back to
epoll. libxev only falls back when ring creation actually fails, so ring allocation for uid 1000
is failing right now. (Dividing the cap by the ring count gives ~29.9 KB/ring, which is a plausible
figure for a minimal ring's pinned pages — but it is derived *from* the cap, so it corroborates
nothing on its own and is not evidence.)

`/proc/<pid>/status` is actively misleading here: io_uring charges `user_struct->locked_vm`, which
is **per-account, not per-process**, so ghostty reports `VmLck: 0 kB` while sitting at the ceiling.
This is why fd counts, pty counts and process counts all looked healthy.

## Ruled out (with evidence)

- **Nix store-path rot** — all 25 store roots in `/proc/2998071/environ` exist; zero deleted store
  mappings in `/proc/…/maps`; the only GC since July ran 11.5 h *before* ghostty started.
- **Config / launch chain** — `mod+t` → `$TERMINAL` → bare `ghostty` (`~/.config/hypr/keybindings.conf:22`
  overrides HyDE's `hyde-shell`). `command=zsh` resolves and is executable.
  `ghostty +validate-config` exits 0. Config is byte-identical to the repo source.
- **fd / pty / process exhaustion** — 38 fds vs 524288; 16 ptys vs 4096; 301 procs vs 126618.
- **`linux-cgroup` / transient-scope path** — `linux-cgroup-hard-fail` is `false` (default), so a
  scope failure is tolerated and exec proceeds anyway; and the failure happens at `initSurface()`,
  *upstream of fork*. The missing scope is a consequence, not a cause.
- **`systemctl --user daemon-reexec`** — tested explicitly: 1 stall in 8 spawns across 4 reexec
  cycles, and the stall did not repeat in 6 consecutive follow-ups. Not the trigger. (That one
  stall coincided with three investigation subagents — i.e. more node processes, more rings.)
- **systemd-oomd, zsh init hang, xdg-desktop-portal, GPU/i915 errors, suspend/resume** — all
  checked and cleared; details in git history of this file.

## Fixes

### 1. Stop ghostty depending on io_uring (targeted, one line)

`modules/hm/home/ghostty.conf`:

```
async-backend = epoll
```

Ghostty then never requests a ring. Verified safe by the probes above — a fresh ghostty already
runs on epoll today and behaves identically. Not a *guaranteed* cure in general
(`error.SystemResources` covers a family of exhaustions), but it removes this specific one.

Verified against the binary: `async-backend` accepts `auto` (default), `epoll`, `io_uring`, and
`ghostty +validate-config` accepts `epoll` cleanly. This takes effect on the next ghostty start,
no rebuild strictly required if the file is edited directly — but edit the repo source so it
survives, since `~/.config/ghostty/config` is a mutable copy written by `modules/hm/files.nix`.

### 2. Raise the memlock ceiling (systemic, fixes it for every app)

8 MiB is the systemd default and is far too small for a machine running ~93 io_uring-using
processes. In the NixOS config:

```nix
systemd.settings.Manager.DefaultLimitMEMLOCK = "256M";
systemd.user.settings.Manager.DefaultLimitMEMLOCK = "256M";
```

Both are needed: the system manager governs the graphical session, the user manager governs
`app.slice`. Requires `sudo nixos-rebuild switch` and a re-login to take effect.

### 3. Know the driver

The ring pressure is Claude Code plus ~10 `npm exec` MCP servers. It returns whenever the MCP
server count climbs. Fix 1 makes ghostty immune; fix 2 raises the ceiling for everything else.

**Upgrading is not an option:** 1.3.1 is upstream's newest tag, and nixpkgs ships 1.3.1 in every
channel (unstable, 25.11, 26.05). No released fix exists; the error is still swallowed on `main`
(`src/apprt/gtk/class/surface.zig` catches `initSurface()` and only `log.warn`s).

### Immediate relief, no rebuild

Restarting ghostty makes it pick epoll at startup (see table above). The tmux surface survives via
`tmux attach`; the mosh client does not.

## Ghostty has no log

`/proc/2998071/fd/1` and `fd/2` both point at `/dev/null` — Hyprland launched it with output
discarded, so **this instance cannot report an error even as it fails**. That is why the journal,
`coredumpctl` and `~/.cache/ghostty/` are all empty. To capture the failure directly:

```sh
ghostty --gtk-single-instance=false >/tmp/ghostty.log 2>&1
```

Discriminator if it recurs: `err=error.SystemResources` → this bug. Any
`gtk_post_fork` / `gtk_pre_exec` transient-scope line → something with no upstream precedent.

## Separate real bug found (unrelated to the above)

`tmux-main.service` is in a permanent restart loop — **437 restarts and climbing, one failed exec
every ~1 s**:

```
Unable to locate executable
'/nix/store/03vskx80fc614f2ff5xz9sibnh4ig1jd-zsh-5.9/bin/zsh': No such file or directory
status=203/EXEC
```

An untracked hand-written drop-in at `~/.config/systemd/user/tmux-main.service.d/override.conf`
(dated Jun 12) pins a garbage-collected `zsh-5.9`, overriding the correct `ExecStart` in
`/etc/systemd/user/tmux-main.service`, which already points at the live `zsh-5.9.1`. The override's
own comment says it was *"safe to delete after the next nixos-rebuild switch"* — that never
happened. Consequence: `cz()` in `~/.zsh_dori` calls `systemctl --user start tmux-main`, so the
persistent agent tmux server never comes up.

```sh
rm -r ~/.config/systemd/user/tmux-main.service.d
systemctl --user daemon-reload
systemctl --user restart tmux-main.service
```

## Monitoring

`docs/ghostty-watch-stall.sh` polls the invariant

```
N windows == N renderer threads == N ptmx fds == N shell children == N surface scopes
```

and dumps threads, fds, clients, scopes and the systemd job queue the moment it diverges.
