#!/bin/bash
# Role-aware Bootstrap Script
# Author: Koray Karaman

ROLE="$1"
PGHA_DIR="${HOME}/pg-ha"
CONFIG_DIR="${PGHA_DIR}/configs"

mkdir -p "$CONFIG_DIR"
cd "$PGHA_DIR" || exit 1

echo "[*] Downloading setup.sh..."
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/setup.sh -O setup.sh

case "$ROLE" in
  master)
    echo "[*] Preparing master node files..."
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/postgresql.conf -O "$CONFIG_DIR/postgresql.conf"
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pg_hba.conf -O "$CONFIG_DIR/pg_hba.conf"
    ;;
  replica)
    echo "[*] Preparing replica node files..."
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/postgresql.conf -O "$CONFIG_DIR/postgresql.conf"
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pg_hba.conf -O "$CONFIG_DIR/pg_hba.conf"
    ;;
  pgpool)
    echo "[*] Preparing pgpool node files..."
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pgpool.conf -O "$CONFIG_DIR/pgpool.conf"
    ;;
  pgha)
    echo "[*] Preparing pgha node files..."
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/network-setup.yaml -O "$CONFIG_DIR/network-setup.yaml"
    ;;
  monitoring)
    echo "[*] Preparing monitoring node files..."
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/prometheus.yml -O "$CONFIG_DIR/prometheus.yml"
    ;;
  *)
    echo "[!] ERROR: Unknown role '$ROLE'. Valid roles: master, replica, pgpool, pgha, monitoring"
    exit 1
    ;;
esac

echo "[*] Downloading healthcheck and verify scripts..."
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/healthcheck.sh -O healthcheck.sh
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/verify.sh -O verify.sh

chmod +x setup.sh healthcheck.sh verify.sh
echo "[+] Bootstrap complete for role: $ROLE"
