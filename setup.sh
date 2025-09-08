#!/bin/bash
# PostgreSQL HA Cluster Setup Script (Dynamic Version)
# Author: Koray Karaman

ROLE="$1"
MASTER_IP="$2"
PGHA_DIR="/opt/pg-ha"
CONFIG_DIR="$PGHA_DIR/configs"

# PostgreSQL version detection
detect_pg_version() {
  pg_lsclusters | awk 'NR==2 {print $1}'
}

# PostgreSQL configuration
configure_postgres() {
  echo "[*] Applying PostgreSQL configuration..."

  PG_VERSION=$(pg_lsclusters | awk 'NR==2 {print $1}')
  PG_CONF_DIR="/etc/postgresql/$PG_VERSION/main"
  CONFIG_DIR="$PGHA_DIR/configs"

  # Ensure config directory exists
  mkdir -p "$CONFIG_DIR"

  # Download config files if missing
  if [ ! -f "$CONFIG_DIR/postgresql.conf" ]; then
    echo "[*] Downloading postgresql.conf..."
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/postgresql.conf -O "$CONFIG_DIR/postgresql.conf"
  fi

  if [ ! -f "$CONFIG_DIR/pg_hba.conf" ]; then
    echo "[*] Downloading pg_hba.conf..."
    wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pg_hba.conf -O "$CONFIG_DIR/pg_hba.conf"
  fi

  # Apply configs
  if [ -d "$PG_CONF_DIR" ]; then
    sudo systemctl stop postgresql
    sudo cp "$CONFIG_DIR/postgresql.conf" "$PG_CONF_DIR/postgresql.conf"
    sudo cp "$CONFIG_DIR/pg_hba.conf" "$PG_CONF_DIR/pg_hba.conf"
    sudo systemctl start postgresql
    echo "[+] PostgreSQL configuration applied to version $PG_VERSION"
  else
    echo "[!] ERROR: PostgreSQL config directory not found: $PG_CONF_DIR"
    exit 1
  fi
}


# Master node setup
setup_master() {
  echo "=== Starting setup for role: master ==="
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y postgresql postgresql-contrib

  configure_postgres

  echo "[*] Creating replication user..."
  sudo -u postgres psql -c "CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'replicator';"

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