#!/bin/bash
# PostgreSQL HA Cluster Setup Script (Full Version)
# Author: Koray Karaman

ROLE="$1"
MASTER_IP="$2"
PGHA_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$PGHA_DIR/configs"

detect_pg_version() {
  pg_lsclusters | awk 'NR==2 {print $1}'
}

ensure_postgres_user() {
  if ! id "postgres" &>/dev/null; then
    echo "[*] 'postgres' system user not found. Creating..."
    sudo adduser --system --group --home /var/lib/postgresql postgres
    echo "[+] 'postgres' system user created."
  fi
}

prompt_postgres_password() {
  echo -n "🔐 Enter password for PostgreSQL 'postgres' user: "
  read -s POSTGRES_PW
  echo
}

ensure_cluster_exists() {
  PG_VERSION=$(detect_pg_version)
  if [ -z "$PG_VERSION" ]; then
    PG_VERSION=$(psql -V | awk '{print $3}' | cut -d. -f1)
    echo "[*] No cluster found. Creating PostgreSQL $PG_VERSION cluster..."
    sudo pg_createcluster "$PG_VERSION" main --start
  fi
}

apply_config_files() {
  echo "[*] Applying PostgreSQL configuration..."
  PG_VERSION=$(detect_pg_version)
  PG_CONF_DIR="/etc/postgresql/$PG_VERSION/main"

  sudo mkdir -p "$CONFIG_DIR"

  [ ! -f "$CONFIG_DIR/postgresql.conf" ] && \
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/postgresql.conf -O "$CONFIG_DIR/postgresql.conf"

  [ ! -f "$CONFIG_DIR/pg_hba.conf" ] && \
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pg_hba.conf -O "$CONFIG_DIR/pg_hba.conf"

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
  sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$POSTGRES_PW';"
}

create_replication_user() {
  echo "[*] Creating replication user..."
  sudo -u postgres psql -c "CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'replicator';"
}

setup_master() {
  echo "=== Starting setup for role: master ==="
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y postgresql postgresql-contrib

  ensure_postgres_user
  prompt_postgres_password
  ensure_cluster_exists
  apply_config_files
  fix_pg_hba_auth
  set_postgres_password
  create_replication_user

  echo "[+] Master node setup complete."
  echo "=== master setup finished ==="
}

setup_replica() {
  echo "=== Starting setup for role: replica ==="
  if [ -z "$MASTER_IP" ]; then
    echo "[!] ERROR: Master IP not provided."
    exit 1
  fi

  sudo apt update && sudo apt install -y postgresql

  ensure_postgres_user
  prompt_postgres_password
  ensure_cluster_exists

  PG_VERSION=$(detect_pg_version)
  DATA_DIR="/var/lib/postgresql/$PG_VERSION/main"

  echo "[*] Stopping PostgreSQL and cleaning data directory..."
  sudo systemctl stop postgresql
  sudo -u postgres rm -rf "$DATA_DIR"

  echo "[*] Performing base backup from master..."
  sudo -u postgres pg_basebackup -h "$MASTER_IP" -D "$DATA_DIR" -U replicator -P -R

  apply_config_files
  fix_pg_hba_auth
  set_postgres_password

  echo "[+] Replica node setup complete."
  echo "=== replica setup finished ==="
}

setup_pgpool() {
  echo "=== Starting setup for role: pgpool ==="
  sudo apt update && sudo apt install -y pgpool2
  echo "[*] Pgpool installed."
  echo "=== pgpool setup finished ==="
}

setup_pgha() {
  echo "=== Starting setup for role: pgha ==="
  sudo apt update && sudo apt install -y keepalived
  echo "[*] Keepalived installed."
  echo "=== pgha setup finished ==="
}

setup_monitoring() {
  echo "=== Starting setup for role: monitoring ==="
  sudo apt update && sudo apt install -y prometheus grafana
  echo "[*] Prometheus and Grafana installed."
  echo "=== monitoring setup finished ==="
}

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
