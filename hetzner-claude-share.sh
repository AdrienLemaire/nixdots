#!/usr/bin/env bash
# Make the dev box's claudeA (~/.claude-adrien) and claudeF (~/.claude-founders)
# accounts share rules, memory and settings, like modules/hm/claude-accounts.nix
# does on the laptop. The box has no home-manager, so a systemd timer re-applies
# the same scripts hourly and at boot.
#
# Usage: ./hetzner-claude-share.sh [ssh-host]     (default: md-atlas)
#        SSH_OPTS="-i key" adds options to every ssh/scp call.
# Idempotent. Copies the laptop's global CLAUDE.md as the box's shared rules.
# The settings base (/root/.claude-adrien/settings-shared.json) stays on the box:
# it holds work-org details and this repo is public. Without one, only memory
# and rules are shared.
set -euo pipefail

HOST="${1:-md-atlas}"
read -ra OPTS <<<"${SSH_OPTS:-}"
SCRIPTS="$(dirname "$0")/modules/hm/scripts"
PRIMARY=/root/.claude-adrien
SECONDARY=/root/.claude-founders

ssh "${OPTS[@]}" "$HOST" 'command -v jq >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jq'

for name in claude-share-memory claude-share-settings claude-accounts-check; do
  scp -q "${OPTS[@]}" "$SCRIPTS/$name.sh" "$HOST:/usr/local/bin/$name"
done
scp -q "${OPTS[@]}" "$HOME/.claude-adrien/CLAUDE.md" "$HOST:$PRIMARY/CLAUDE.md"

# Unquoted on purpose: PRIMARY/SECONDARY are expanded here, before sending.
# shellcheck disable=SC2087
ssh "${OPTS[@]}" "$HOST" bash -s <<EOF
set -euo pipefail
chmod 755 /usr/local/bin/claude-share-memory /usr/local/bin/claude-share-settings /usr/local/bin/claude-accounts-check
chmod 600 $PRIMARY/CLAUDE.md
ln -sfn $PRIMARY/CLAUDE.md $SECONDARY/CLAUDE.md

cat >/etc/systemd/system/claude-share.service <<'UNIT'
[Unit]
Description=Share rules, memory and settings between the two Claude accounts

[Service]
Type=oneshot
ExecStart=/usr/local/bin/claude-share-settings $PRIMARY/settings-shared.json $PRIMARY/settings.json $SECONDARY/settings.json
ExecStart=/usr/local/bin/claude-share-memory $PRIMARY $SECONDARY
UNIT

cat >/etc/systemd/system/claude-share.timer <<'UNIT'
[Unit]
Description=Re-apply Claude account sharing hourly

[Timer]
OnBootSec=2min
OnUnitActiveSec=1h

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now claude-share.timer
systemctl start claude-share.service
journalctl -u claude-share.service -n 30 --no-pager -o cat
claude-accounts-check $PRIMARY $SECONDARY
EOF
