#!/bin/bash
CONFIG_DIR="$(cd "$(dirname "$0")/../configs" && pwd)"

cd /tmp || true

echo "=== Setting up keepalived node ==="
sudo apt update && sudo apt install -y keepalived

# İleride: /etc/keepalived/keepalived.conf dosyası buraya entegre edilebilir
# VIP, healthcheck scripti, notify master/backup ayarları eklenebilir

echo "[✓] Keepalived installed."