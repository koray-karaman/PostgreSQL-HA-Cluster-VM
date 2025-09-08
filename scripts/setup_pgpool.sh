#!/bin/bash
CONFIG_DIR="$(cd "$(dirname "$0")/../configs" && pwd)"

cd /tmp || true

echo "=== Setting up pgpool node ==="
sudo apt update && sudo apt install -y pgpool2

# İleride: pgpool.conf, pcp.conf, watchdog ayarları buraya entegre edilebilir

echo "[✓] Pgpool installed."