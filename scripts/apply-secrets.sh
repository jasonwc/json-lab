#!/usr/bin/env bash
set -euo pipefail

# Apply Kubernetes secrets from environment variables.
# Source .envrc first (or use direnv), then run this script.
#
# Usage:
#   source .envrc && ./scripts/apply-secrets.sh
#   # or with direnv: just ./scripts/apply-secrets.sh

NAMESPACE="media"

# Ensure namespace exists
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "--- VPN credentials (gluetun) ---"
: "${VPN_SERVICE_PROVIDER:?Set VPN_SERVICE_PROVIDER in .envrc}"
: "${VPN_TYPE:?Set VPN_TYPE in .envrc}"
: "${OPENVPN_USER:?Set OPENVPN_USER in .envrc}"
: "${OPENVPN_PASSWORD:?Set OPENVPN_PASSWORD in .envrc}"

kubectl -n "$NAMESPACE" create secret generic vpn-credentials \
  --from-literal=VPN_SERVICE_PROVIDER="$VPN_SERVICE_PROVIDER" \
  --from-literal=VPN_TYPE="$VPN_TYPE" \
  --from-literal=OPENVPN_USER="$OPENVPN_USER" \
  --from-literal=OPENVPN_PASSWORD="$OPENVPN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "  Applied vpn-credentials secret"

echo "--- Plex claim token ---"
if [ -n "${PLEX_CLAIM:-}" ]; then
  kubectl -n "$NAMESPACE" create secret generic plex-claim \
    --from-literal=token="$PLEX_CLAIM" \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "  Applied plex-claim secret"
else
  echo "  Skipped (PLEX_CLAIM not set — get one from https://plex.tv/claim)"
fi

echo ""
echo "=== Monitoring namespace ==="
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo "--- Grafana admin password ---"
: "${GRAFANA_ADMIN_PASSWORD:?Set GRAFANA_ADMIN_PASSWORD in .envrc}"

kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=password="$GRAFANA_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "  Applied grafana-admin secret"

echo ""
echo "Done. Secrets:"
echo "  media namespace:"
kubectl -n "$NAMESPACE" get secrets
echo "  monitoring namespace:"
kubectl -n monitoring get secrets
