#!/usr/bin/env bash
# Provision the Hetzner CX53 dev box end-to-end.
# Usage:  HCLOUD_TOKEN=xxxxx ./hetzner-provision.sh
# Idempotent: re-running reuses the existing SSH key / server if present.
set -euo pipefail

: "${HCLOUD_TOKEN:?Set HCLOUD_TOKEN to your Hetzner API token (Read & Write)}"
export HCLOUD_TOKEN

SERVER_NAME="${SERVER_NAME:-md-atlas-devbox}"
SERVER_TYPE="${SERVER_TYPE:-cx53}"          # 16 vCPU / 32 GB / 320 GB
LOCATION="${LOCATION:-hel1}"                # Helsinki
IMAGE="${IMAGE:-ubuntu-24.04}"
SSH_KEY_NAME="${SSH_KEY_NAME:-hetzner_claude}"
SSH_PUB="${SSH_PUB:-$HOME/.ssh/hetzner_claude.pub}"
SSH_PRIV="${SSH_PRIV:-$HOME/.ssh/hetzner_claude}"
CLOUD_INIT="${CLOUD_INIT:-$(dirname "$0")/hetzner-cloud-init.yaml}"

hc() { nix run nixpkgs#hcloud -- "$@"; }

echo ">> Verifying token / API access..."
hc server list >/dev/null

echo ">> Ensuring SSH key '$SSH_KEY_NAME' is registered..."
if ! hc ssh-key describe "$SSH_KEY_NAME" >/dev/null 2>&1; then
  hc ssh-key create --name "$SSH_KEY_NAME" --public-key-from-file "$SSH_PUB"
else
  echo "   already registered."
fi

echo ">> Creating server '$SERVER_NAME' ($SERVER_TYPE @ $LOCATION, $IMAGE)..."
if ! hc server describe "$SERVER_NAME" >/dev/null 2>&1; then
  hc server create \
    --name "$SERVER_NAME" \
    --type "$SERVER_TYPE" \
    --image "$IMAGE" \
    --location "$LOCATION" \
    --ssh-key "$SSH_KEY_NAME" \
    --user-data-from-file "$CLOUD_INIT"
else
  echo "   server already exists — reusing."
fi

IP="$(hc server ip "$SERVER_NAME")"
echo ">> Server IP: $IP"

echo ">> Waiting for SSH + cloud-init to finish (this takes ~2-4 min)..."
for i in $(seq 1 60); do
  if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 \
       -i "$SSH_PRIV" "root@$IP" 'test -f /root/.devbox-ready' 2>/dev/null; then
    echo "   cloud-init complete."
    break
  fi
  sleep 10
  printf '.'
done
echo

cat <<EOF

============================================================
  Dev box ready:  $SERVER_NAME  ($SERVER_TYPE)  @  $IP
============================================================

Connect (persistent tmux auto-attaches on login):
    ssh -i $SSH_PRIV root@$IP

Or with mosh (survives laptop sleep / network changes — recommended):
    mosh --ssh="ssh -i $SSH_PRIV" root@$IP

Inside, you're dropped into tmux session 'main'. First time:
    claude            # will prompt for auth (login or ANTHROPIC_API_KEY)

Detach from tmux:  Ctrl-b then d   (session keeps running on the server)
Re-attach later:   just ssh/mosh back in.

Manage the box:
    HCLOUD_TOKEN=... nix run nixpkgs#hcloud -- server poweroff $SERVER_NAME
    HCLOUD_TOKEN=... nix run nixpkgs#hcloud -- server delete   $SERVER_NAME
============================================================
EOF
