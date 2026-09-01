#!/usr/bin/env bash
# Screen brightness across every connected monitor.
#
# HyDE's brightnesscontrol.sh drives brightnessctl's *default* device, which on
# this machine is intel_backlight -- the laptop panel and nothing else. External
# monitors have no /sys/class/backlight entry at all; they are only reachable
# over DDC/CI (VCP feature 0x10), which needs `hardware.i2c.enable` for the
# /dev/i2c-* nodes. See modules/system/display.nix.
#
# So this wraps rather than replaces: delegate the internal panel and the OSD to
# HyDE, then mirror the resulting percentage onto every DDC-capable external.
#
# Mirroring an *absolute* percentage instead of applying the same relative step
# is deliberate. ddcutil takes ~200 ms per monitor, so a held-down key drops
# writes at the flock below; absolute targets make each drop self-correct on the
# next keypress instead of letting the panels drift apart.

set -uo pipefail

hyde_script="${HOME}/.local/lib/hyde/brightnesscontrol.sh"
runtime="${XDG_RUNTIME_DIR:-/tmp}"
cache="${runtime}/brightness-all.buses"
lock="${runtime}/brightness-all.lock"

# Fingerprint the set of connected outputs so docking or unplugging rebuilds the
# cache on its own -- cheaper and more correct than a TTL, and it avoids having
# to listen for Hyprland monitor events.
connected_fingerprint() {
  grep -l '^connected$' /sys/class/drm/card*-*/status 2>/dev/null | sort | tr '\n' ' '
}

# `ddcutil detect` probes every I2C bus and is far too slow for the hot path, so
# the per-bus capability check lives here and runs only when the cache is stale.
# Buses that do not answer a brightness read are dropped: DDC/CI is routinely
# absent on portable side-panels and often does not survive a USB-C hub.
build_cache() {
  local bus vcp max
  printf '#%s\n' "$(connected_fingerprint)"
  ddcutil detect --brief 2>/dev/null |
    awk '/^Invalid/ { ok = 0 } /^Display/ { ok = 1 } ok && /I2C bus:/ { sub(".*/dev/i2c-", ""); print }' |
    while read -r bus; do
      [[ -n ${bus} ]] || continue
      # --brief getvcp prints "VCP 10 C <current> <max>"; keep the max so a
      # monitor whose brightness range is not 0-100 still scales correctly.
      vcp=$(ddcutil --bus "${bus}" --brief getvcp 10 2>/dev/null)
      max=${vcp##* }
      [[ ${max} =~ ^[0-9]+$ ]] && printf '%s %s\n' "${bus}" "${max}"
    done
}

ensure_cache() {
  [[ -s ${cache} && $(head -1 "${cache}") == "#$(connected_fingerprint)" ]] && return
  # Only commit a cache that actually found a bus. A probe that comes up empty is
  # usually transient -- i2c access not live yet, a monitor still asleep, a hub
  # glitch -- and caching that emptiness would silently disable every external
  # until the monitor set changed.
  build_cache >"${cache}.tmp" &&
    [[ $(grep -cv '^#' "${cache}.tmp") -gt 0 ]] &&
    mv "${cache}.tmp" "${cache}"
}

# brightnessctl -m prints "<device>,<class>,<raw>,<pct>%,<max>".
# Note: if swayosd is ever enabled, HyDE's script hands off to swayosd-client and
# returns before the backlight settles, so this can read a stale value. The
# convergence loop below absorbs that.
internal_percent() {
  brightnessctl -m | cut -d, -f4 | tr -d '%'
}

mirror_externals() {
  local pct=$1 bus max
  # No cache means the probe found no DDC-capable external; nothing to mirror.
  [[ -s ${cache} ]] || return 0
  while read -r bus max; do
    [[ ${bus} == \#* || -z ${bus} ]] && continue
    # --noverify skips the read-back ddcutil otherwise does after every write,
    # which roughly halves the per-monitor cost.
    ddcutil --bus "${bus}" --noverify setvcp 10 "$((pct * max / 100))" >/dev/null 2>&1 &
  done <"${cache}"
  wait
}

case ${1:-} in
i | -i | d | -d) ;;
*)
  echo "usage: $(basename "$0") <i|d> [step]" >&2
  exit 1
  ;;
esac

# Internal panel first: it owns the OSD, so the feedback is immediate even when
# the DDC writes below are still in flight or skipped.
"${hyde_script}" "$@"

# Detached so a held key never queues up behind ddcutil, and non-blocking flock
# so concurrent presses collapse into one write instead of piling up.
{
  exec 9>"${lock}"
  flock -n 9 || exit 0
  ensure_cache
  # Follow the internal panel until it stops moving. Presses that arrived while
  # the lock was held are dropped, so a single mirror would leave the externals
  # at whatever percentage the *first* press of a hold saw -- and hold-to-brighten
  # is the normal way these keys get used. Re-reading until two passes agree
  # costs one extra DDC round after the burst ends and lands on the final value.
  last=""
  while cur=$(internal_percent); [[ ${cur} != "${last}" ]]; do
    last=${cur}
    mirror_externals "${cur}"
  done
} &
