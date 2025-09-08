#!/bin/bash
# PostgreSQL HA Cluster Bootstrap Script
# Author: Koray Karaman

PGHA_DIR="${HOME}/pg-ha"
CONFIG_DIR="${PGHA_DIR}/configs"

echo "[*] Creating working directory: $PGHA_DIR"
mkdir -p "$CONFIG_DIR"
cd "$PGHA_DIR" || exit 1

echo "[*] Downloading setup.sh..."
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/setup.sh -O setup.sh

echo "[*] Downloading config files..."
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/postgresql.conf -O "$CONFIG_DIR/postgresql.conf"
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pg_hba.conf -O "$CONFIG_DIR/pg_hba.conf"
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/network-setup.yaml -O "$CONFIG_DIR/network-setup.yaml"

echo "[*] Downloading healthcheck and verify scripts..."
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/healthcheck.sh -O healthcheck.sh
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/verify.sh -O verify.sh

echo "[*] Setting executable permissions..."
chmod +x setup.sh healthcheck.sh verify.sh

echo "[+] Bootstrap complete. You can now run:"
echo "    ./setup.sh master"
echo "    ./setup.sh replica <MASTER_IP>"
echo "    ./setup.sh pgpool"
echo "    ./setup.sh pgha"
echo "    ./setup.sh monitoring"
