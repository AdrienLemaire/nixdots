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
