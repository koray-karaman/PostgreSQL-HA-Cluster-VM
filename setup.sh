#!/bin/bash
# PostgreSQL HA Cluster Setup Script (Dynamic Version)
# Author: Koray Karaman

ROLE="$1"
PGHA_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$PGHA_DIR/configs"

detect_pg_version() {
  pg_lsclusters | awk 'NR==2 {print $1}'
}

ensure_cluster_exists() {
  PG_VERSION=$(detect_pg_version)
  if [ -z "$PG_VERSION" ]; then
    echo "[*] No cluster found. Creating PostgreSQL cluster..."
    PG_VERSION=$(psql -V | awk '{print $3}' | cut -d. -f1)
    sudo pg_createcluster "$PG_VERSION" main --start
  fi
}

apply_config_files() {
  echo "[*] Applying PostgreSQL configuration..."
  PG_VERSION=$(detect_pg_version)
  PG_CONF_DIR="/etc/postgresql/$PG_VERSION/main"

  sudo mkdir -p "$CONFIG_DIR"

  # Download configs if missing
  [ ! -f "$CONFIG_DIR/postgresql.conf" ] && \
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/postgresql.conf -O "$CONFIG_DIR/postgresql.conf"

  [ ! -f "$CONFIG_DIR/pg_hba.conf" ] && \
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pg_hba.conf -O "$CONFIG_DIR/pg_hba.conf"

  # Apply configs
  sudo cp "$CONFIG_DIR/postgresql.conf" "$PG_CONF_DIR/postgresql.conf"
  sudo cp "$CONFIG_DIR/pg_hba.conf" "$PG_CONF_DIR/pg_hba.conf"
  sudo systemctl restart postgresql
  echo "[+] Configuration applied to PostgreSQL $PG_VERSION"
}

fix_pg_hba_auth() {
  PG_VERSION=$(detect_pg_version)
  PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
  echo "[*] Switching peer auth to md5 for postgres user..."
  sudo sed -i 's/^local\s\+all\s\+postgres\s\+peer/local all postgres md5/' "$PG_HBA"
  sudo systemctl restart postgresql
}

set_postgres_password() {
  echo "[*] Setting password for postgres user..."
  sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
}

create_replication_user() {
  echo "[*] Creating replication user..."
  sudo -u postgres psql -c "CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'replicator';"
}

setup_master() {
  echo "=== Starting setup for role: master ==="
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y postgresql postgresql-contrib

  ensure_cluster_exists
  apply_config_files
  fix_pg_hba_auth
  set_postgres_password
  create_replication_user

  echo "[+] Master node setup complete."
  echo "=== master setup finished ==="
}

# Replica node setup
setup_replica() {
  echo "=== Starting setup for role: replica ==="
  if [ -z "$MASTER_IP" ]; then
    echo "[!] ERROR: Master IP not provided."
    exit 1
  fi

  sudo apt update && sudo apt upgrade -y
  sudo apt install -y postgresql

  echo "[*] Stopping PostgreSQL and cleaning data directory..."
  sudo systemctl stop postgresql
  sudo -u postgres rm -rf /var/lib/postgresql/*

  echo "[*] Performing base backup from master..."
  sudo -u postgres pg_basebackup -h "$MASTER_IP" -D /var/lib/postgresql/$(detect_pg_version)/main -U replicator -P -R

  configure_postgres

  echo "[+] Replica node setup complete."
  echo "=== replica setup finished ==="
}

# Pgpool setup
setup_pgpool() {
  echo "=== Starting setup for role: pgpool ==="
  sudo apt update && sudo apt install -y pgpool2
  echo "[*] Pgpool installed."
  # Additional config steps can be added here
  echo "=== pgpool setup finished ==="
}

# PGHA setup
setup_pgha() {
  echo "=== Starting setup for role: pgha ==="
  sudo apt update && sudo apt install -y keepalived
  echo "[*] PGHA components installed."
  # Additional config steps can be added here
  echo "=== pgha setup finished ==="
}

# Monitoring setup
setup_monitoring() {
  echo "=== Starting setup for role: monitoring ==="
  sudo apt update && sudo apt install -y prometheus grafana
  echo "[*] Prometheus and Grafana installed."
  # Additional config steps can be added here
  echo "=== monitoring setup finished ==="
}

# Main dispatcher
case "$ROLE" in
  master)
    setup_master
    ;;
  replica)
    setup_replica
    ;;
  pgpool)
    setup_pgpool
    ;;
  pgha)
    setup_pgha
    ;;
  monitoring)
    setup_monitoring
    ;;
  *)
    echo "[!] ERROR: Unknown role '$ROLE'. Valid roles: master, replica, pgpool, pgha, monitoring"
    exit 1
    ;;
esac