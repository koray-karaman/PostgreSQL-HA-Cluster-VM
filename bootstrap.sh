#!/bin/bash
# Role-aware Bootstrap Script
# Author: Koray Karaman

ROLE="$1"
PGHA_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[*] Downloading setup.sh..."
wget https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/setup.sh -O "$PGHA_DIR/setup.sh"

echo "[*] Creating scripts directory..."
mkdir -p "$PGHA_DIR/scripts"

echo "[*] Downloading role-based setup scripts..."
for script in setup_master.sh setup_replica.sh setup_pgpool.sh setup_pgha.sh setup_monitoring.sh; do
  wget "https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/scripts/$script" -O "$PGHA_DIR/scripts/$script"
  chmod +x "$PGHA_DIR/scripts/$script"
done

echo "[*] Preparing master node files..."
mkdir -p "$PGHA_DIR/configs"
wget https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/postgresql.conf -O "$PGHA_DIR/configs/postgresql.conf"
wget https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pg_hba.conf -O "$PGHA_DIR/configs/pg_hba.conf"

echo "[*] Downloading healthcheck and verify scripts..."
wget https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/scripts/healthcheck.sh -O "$PGHA_DIR/scripts/healthcheck.sh"
wget https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/scripts/verify.sh -O "$PGHA_DIR/scripts/verify.sh"
chmod +x "$PGHA_DIR/scripts/healthcheck.sh" "$PGHA_DIR/scripts/verify.sh"

echo "[+] Bootstrap complete for role: $ROLE"