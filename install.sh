#!/usr/bin/env bash
#
# install-cloudflared.sh — installiert nur cloudflared und registriert
# den Tunnel-Service. Kein ISO-Server-Setup, kein nginx.
#
# Vor dem Ausführen: CLOUDFLARE_TUNNEL_TOKEN unten eintragen.
#
#   sudo ./install-cloudflared.sh

set -euo pipefail

CLOUDFLARE_TUNNEL_TOKEN="eyJhIjoiNDBjMDMyZjk4YmFjZTA0NzJhZjA3NDIyMGEzNjdjNzUiLCJ0IjoiYjMzYmI4MmMtNjMwZS00MzFjLWE3YmMtY2VkNGMyOTU5YjBmIiwicyI6IlpHWTBPR1pqTW1VdE5qTTBNaTAwWlRFeUxUZ3haV1V0TjJFMk5HRXlNVFEzT1RBMyJ9"

if [[ $EUID -ne 0 ]]; then
    echo "Bitte mit sudo/als root ausführen: sudo ./install-cloudflared.sh"
    exit 1
fi

if [[ "$CLOUDFLARE_TUNNEL_TOKEN" == "PASTE_YOUR_TOKEN_HERE" ]]; then
    echo "Bitte zuerst CLOUDFLARE_TUNNEL_TOKEN oben im Skript eintragen."
    exit 1
fi

echo "==> Cloudflare-GPG-Key hinzufügen"
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null

echo "==> Repo hinzufügen"
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list

echo "==> cloudflared installieren"
apt-get update
apt-get install -y cloudflared

echo "==> Tunnel-Service registrieren"
cloudflared service install "$CLOUDFLARE_TUNNEL_TOKEN"

echo
echo "==> Fertig. Status prüfen: systemctl status cloudflared"
