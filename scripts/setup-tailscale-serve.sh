#!/bin/bash
# ==============================================================================
# Tailscale Serve Virtual Services Setup Script
# Orchestrator Node Ingress Gateway Configuration
# ==============================================================================
set -euo pipefail

# Ensure script runs with LF line endings
replace_crlf() {
    if [ -f "$0" ]; then
        sed -i 's/\r$//' "$0" 2>/dev/null || true
    fi
}
replace_crlf

echo "==> [Tailscale Serve] Resetting existing virtual service routes..."
sudo tailscale serve reset || true

# List of Virtual Services to expose via TLS-terminated Tailscale Serve
SERVICES=(
    "svc:vaultwarden"
    "svc:uptime-kuma"
    "svc:homeassistant"
    "svc:ezbk"
    "svc:ff3"
    "svc:lmstudio"
    "svc:chat"
)


echo "==> [Tailscale Serve] Provisioning Virtual Services to Caddy Proxy (127.0.0.1:80)..."
for svc in "${SERVICES[@]}"; do
    echo "    --> Registering ${svc} (https:443 -> http://127.0.0.1:80)..."
    sudo tailscale serve --bg --service="${svc}" --https=443 http://127.0.0.1:80
done

echo "==> [Tailscale Serve] Current Active Configuration:"
sudo tailscale serve status || true
echo "==> [Tailscale Serve] Provisioning Complete! ✅"
