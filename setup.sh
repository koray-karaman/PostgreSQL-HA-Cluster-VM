#!/bin/bash
ROLE="$1"
MASTER_IP="$2"
PGHA_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$PGHA_DIR/configs"
PG_VERSION=""
DATA_DIR=""

detect_pg_version() {
  local version
  version=$(psql -V | awk '{print $3}' | cut -d. -f1)
  PG_VERSION="$version"
  DATA_DIR="/var/lib/postgresql/$PG_VERSION/main"
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

clean_broken_cluster() {
  echo "[*] Cleaning broken cluster if exists..."
  sudo pg_dropcluster $PG_VERSION main --stop 2>/dev/null || true
  sudo rm -rf /etc/postgresql/$PG_VERSION/main
  sudo rm -rf "$DATA_DIR"
}

ensure_cluster_exists() {
  echo "[*] Creating PostgreSQL $PG_VERSION cluster..."
  sudo pg_createcluster "$PG_VERSION" main --start
}

apply_config_files() {
  echo "[*] Applying PostgreSQL configuration..."
  local conf_dir="/etc/postgresql/$PG_VERSION/main"

  # Yedekle
  sudo cp "$conf_dir/postgresql.conf" "$conf_dir/postgresql.conf.bak"

  # Uygula
  sudo cp "$CONFIG_DIR/postgresql.conf" "$conf_dir/postgresql.conf"
  sudo cp "$CONFIG_DIR/pg_hba.conf" "$conf_dir/pg_hba.conf"

  # data_directory tanımını ekle
  sudo sed -i "/^#*data_directory\s*=.*/d" "$conf_dir/postgresql.conf"
  echo "data_directory = '$DATA_DIR'" | sudo tee -a "$conf_dir/postgresql.conf" > /dev/null

  # Restart
  sudo systemctl restart postgresql@$PG_VERSION-main
  echo "[+] Configuration applied to PostgreSQL $PG_VERSION"
}

fix_pg_hba_auth() {
  local hba="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
  echo "[*] Switching peer auth to md5 for postgres user..."
  sudo sed -i 's/^local\s\+all\s\+postgres\s\+peer/local all postgres md5/' "$hba"
  sudo systemctl restart postgresql@$PG_VERSION-main
}

wait_for_postgres() {
  echo "[*] Waiting for PostgreSQL to become available..."
  for i in {1..30}; do
    if sudo -u postgres /usr/lib/postgresql/$PG_VERSION/bin/psql -p 5432 -c "SELECT 1;" &>/dev/null; then
      echo "[+] PostgreSQL is ready after $i seconds."
      return
    else
      echo "  ... still waiting ($i)"
      sleep 1
    fi
  done
  echo "[!] PostgreSQL did not become ready in time. Aborting."
  exit 1
}

set_postgres_password() {
  echo "[*] Setting password for postgres user..."
  sudo -u postgres /usr/lib/postgresql/$PG_VERSION/bin/psql -p 5432 -c "ALTER USER postgres WITH PASSWORD '$POSTGRES_PW';"
}

create_replication_user() {
  echo "[*] Creating replication user..."
  sudo -u postgres /usr/lib/postgresql/$PG_VERSION/bin/psql -p 5432 -c "CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'replicator';"
}

verify_connection() {
  echo "[*] Verifying connection as 'postgres'..."
  PGPASSWORD="$POSTGRES_PW" psql -U postgres -h localhost -p 5432 -c "SELECT current_user, inet_server_addr();" || {
    echo "[!] Connection verification failed."
    exit 1
  }
  echo "[+] Connection verified successfully."
}

setup_master() {
  echo "=== Starting setup for role: master ==="
  sudo apt update && sudo apt install -y postgresql postgresql-contrib

  detect_pg_version
  clean_broken_cluster
  ensure_postgres_user
  prompt_postgres_password
  ensure_cluster_exists
  apply_config_files
  fix_pg_hba_auth
  wait_for_postgres
  set_postgres_password
  create_replication_user
  verify_connection

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

  detect_pg_version
  ensure_postgres_user
  prompt_postgres_password
  clean_broken_cluster
  ensure_cluster_exists

  echo "[*] Stopping PostgreSQL and cleaning data directory..."
  sudo systemctl stop postgresql@$PG_VERSION-main
  sudo -u postgres rm -rf "$DATA_DIR"

  echo "[*] Performing base backup from master..."
  sudo -u postgres pg_basebackup -h "$MASTER_IP" -D "$DATA_DIR" -U replicator -P -R

  apply_config_files
  fix_pg_hba_auth
  wait_for_postgres
  set_postgres_password
  verify_connection

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