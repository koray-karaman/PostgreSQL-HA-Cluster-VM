#!/bin/bash
# PostgreSQL HA Cluster Setup Script
# Usage: ./setup.sh [master|replica|pgpool|pgha|monitoring] [MASTER_IP if replica]

ROLE=$1
MASTER_IP=$2

if [ -z "$ROLE" ]; then
  echo "Usage: $0 [master|replica|pgpool|pgha|monitoring] [MASTER_IP if replica]"
  exit 1
fi

echo "=== Starting setup for role: $ROLE ==="

update_system() {
  echo "[*] Updating system packages..."
  sudo apt update && sudo apt upgrade -y
}

install_postgres() {
  echo "[*] Installing PostgreSQL..."
  sudo apt install postgresql postgresql-contrib -y
}

configure_postgres() {
  echo "[*] Applying PostgreSQL configuration..."
  sudo systemctl stop postgresql
  sudo cp configs/postgresql.conf /etc/postgresql/15/main/postgresql.conf
  sudo cp configs/pg_hba.conf /etc/postgresql/15/main/pg_hba.conf
}

setup_master() {
  update_system
  install_postgres
  configure_postgres
  echo "[*] Creating replication user..."
  sudo -u postgres psql -c "CREATE ROLE replica WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'replica_pass';"
  sudo systemctl start postgresql
  echo "[+] Master node setup complete."
}

setup_replica() {
  if [ -z "$MASTER_IP" ]; then
    echo "Replica setup requires MASTER_IP"
    exit 1
  fi
  update_system
  install_postgres
  sudo systemctl stop postgresql
  sudo rm -rf /var/lib/postgresql/15/main/*
  echo "[*] Running base backup from master..."
  sudo -u postgres pg_basebackup -h $MASTER_IP -D /var/lib/postgresql/15/main -U replica -P -R
  configure_postgres
  sudo systemctl start postgresql
  echo "[+] Replica node setup complete."
}

setup_pgpool() {
  update_system
  echo "[*] Installing Pgpool-II..."
  sudo apt install pgpool2 -y
  sudo cp configs/pgpool.conf /etc/pgpool2/pgpool.conf
  sudo cp configs/pgpool-healthcheck.conf /etc/pgpool2/pgpool-healthcheck.conf
  sudo systemctl enable pgpool2
  sudo systemctl start pgpool2
  echo "[+] Pgpool node setup complete."
}

setup_pgha() {
  update_system
  echo "[*] Installing Pgpool-II with watchdog..."
  sudo apt install pgpool2 -y
  sudo cp configs/watchdog.conf /etc/pgpool2/watchdog.conf
  sudo systemctl enable pgpool2
  sudo systemctl start pgpool2
  echo "[+] PGHA node setup complete."
}

setup_monitoring() {
  update_system
  echo "[*] Installing Prometheus & Grafana..."
  sudo apt install prometheus grafana -y
  sudo cp monitoring/prometheus.yml /etc/prometheus/prometheus.yml
  sudo systemctl enable prometheus grafana-server
  sudo systemctl start prometheus grafana-server
  echo "[+] Monitoring node setup complete."
}

case $ROLE in
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
    echo "Invalid role: $ROLE"
    exit 1
    ;;
esac

echo "=== $ROLE setup finished ==="
