#!/bin/bash
set -e

echo "Starting Tailscale..."

if [ -n "$TAILSCALE_AUTHKEY" ]; then
  mkdir -p "$TAILSCALE_STATE_DIR"

  tailscaled \
    --state="$TAILSCALE_STATE_DIR/tailscale.state" \
    --socket="$TAILSCALE_SOCKET" \
    --tun=userspace-networking &

  sleep 3

  tailscale up \
    --authkey="$TAILSCALE_AUTHKEY" \
    --hostname="${TAILSCALE_HOSTNAME:-wordpress-cloudrun}" \
    --accept-dns=false \
    --accept-routes \
    $TAILSCALE_EXTRA_ARGS || true
else
  echo "TAILSCALE_AUTHKEY not set, skipping Tailscale"
fi

echo "Starting Apache..."
exec apache2-foreground
