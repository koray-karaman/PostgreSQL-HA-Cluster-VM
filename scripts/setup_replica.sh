#!/bin/bash
cd /tmp || true

PGHA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$PGHA_DIR/configs"
PG_VERSION=""
DATA_DIR=""

detect_pg_version() {
  PG_VERSION=$(psql -V | awk '{print $3}' | cut -d. -f1)
  DATA_DIR="/var/lib/postgresql/$PG_VERSION/main"
}

ensure_postgres_user() {
  if ! id "postgres" &>/dev/null; then
    echo "[*] Creating 'postgres' system user..."
    sudo adduser --system --group --home /var/lib/postgresql postgres
    echo "[+] 'postgres' user created."
  fi
}

prompt_master_ip() {
  read -p "🌐 Enter MASTER IP address: " MASTER_IP
  if [[ ! "$MASTER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[!] Invalid IP format. Aborting."
    exit 1
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
  sudo rm -rf /etc/postgresql/$PG_VERSION/main "$DATA_DIR"
}

ensure_cluster_exists() {
  echo "[*] Creating PostgreSQL $PG_VERSION cluster..."
  sudo pg_createcluster "$PG_VERSION" main --start
}

apply_config_files() {
  echo "[*] Applying PostgreSQL configuration..."
  local conf_dir="/etc/postgresql/$PG_VERSION/main"

  sudo cp "$CONFIG_DIR/postgresql.conf" "$conf_dir/postgresql.conf"
  sudo cp "$CONFIG_DIR/pg_hba.conf" "$conf_dir/pg_hba.conf"

  # Güvenli data_directory ekleme
  sudo sed -i '/^data_directory\s*=.*/d' "$conf_dir/postgresql.conf"
  echo -e "\n# Explicit data directory for HA setup\ndata_directory = '$DATA_DIR'" | sudo tee -a "$conf_dir/postgresql.conf" > /dev/null

  # Ensure IPv6 localhost is allowed
  sudo grep -q "::1/128" "$conf_dir/pg_hba.conf" || echo "host    all    all    ::1/128    scram-sha-256" | sudo tee -a "$conf_dir/pg_hba.conf" > /dev/null
  # Ensure IPv4 localhost is allowed
  sudo grep -q "127.0.0.1/32" "$conf_dir/pg_hba.conf" || echo "host    all    all    127.0.0.1/32    scram-sha-256" | sudo tee -a "$conf_dir/pg_hba.conf" > /dev/null

  sudo systemctl restart postgresql@$PG_VERSION-main
  echo "[+] Configuration applied."
}

fix_pg_hba_auth() {
  local hba="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
  echo "[*] Switching peer auth to md5..."
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
  echo "[*] Setting password for postgres..."
  sudo -u postgres /usr/lib/postgresql/$PG_VERSION/bin/psql -p 5432 -c "ALTER USER postgres WITH PASSWORD '$POSTGRES_PW';"
}

verify_connection() {
  echo "[*] Verifying connection..."
  PGPASSWORD="$POSTGRES_PW" psql -U postgres -h 127.0.0.1 -p 5432 -c "SELECT current_user, inet_server_addr();" || {
    echo "[!] Connection failed."
    exit 1
  }
  echo "[+] Connection verified."
}

setup_replica() {
  echo "=== Setting up replica node ==="
  sudo apt update && sudo apt install -y postgresql

  detect_pg_version
  ensure_postgres_user
  prompt_master_ip
  prompt_postgres_password
  clean_broken_cluster
  ensure_cluster_exists

  echo "[*] Stopping PostgreSQL and cleaning data directory..."
  sudo systemctl stop postgresql@$PG_VERSION-main
  sudo -u postgres rm -rf "$DATA_DIR"

  echo "[*] Performing base backup from master ($MASTER_IP)..."
  sudo -u postgres pg_basebackup -h "$MASTER_IP" -D "$DATA_DIR" -U replicator -P -R

  apply_config_files
  fix_pg_hba_auth
  wait_for_postgres
  set_postgres_password
  verify_connection

  echo "[✓] Replica setup complete."
}

setup_replica