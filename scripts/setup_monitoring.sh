#!/bin/bash
CONFIG_DIR="$(cd "$(dirname "$0")/../configs" && pwd)"

cd /tmp || true

echo "=== Setting up monitoring node ==="
sudo apt update && sudo apt install -y prometheus grafana

# İleride: prometheus.yml, node_exporter, postgres_exporter, grafana dashboards buraya entegre edilebilir

echo "[✓] Monitoring stack installed."