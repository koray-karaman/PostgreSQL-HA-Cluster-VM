#!/bin/bash
cd /tmp || true

PGHA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$PGHA_DIR/configs"
PG_VERSION=""
DATA_DIR=""
MASTER_IP=""
POSTGRES_PW=""
REPL_PASS=""

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

prompt_replicator_password() {
  echo -n "🔐 Enter password for replication user 'replicator': "
  read -s REPL_PASS
  echo
  echo "📣 This must match the password set on the master node."
}

prompt_replica_identity() {
  echo -n "📛 Enter this replica's name (must match master's config): "
  read THIS_REPL_NAME

  echo "[*] Setting application_name for replication..."
  echo -e "\nprimary_conninfo = 'host=$MASTER_IP port=5432 user=replicator password=$REPL_PASS application_name=$THIS_REPL_NAME'" | sudo tee /etc/postgresql/$PG_VERSION/main/postgresql.auto.conf > /dev/null
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

  sudo sed -i '/^data_directory\s*=.*/d' "$conf_dir/postgresql.conf"
  echo -e "\n# Explicit data directory for HA setup\ndata_directory = '$DATA_DIR'" | sudo tee -a "$conf_dir/postgresql.conf" > /dev/null

  sudo grep -q "::1/128" "$conf_dir/pg_hba.conf" || echo "host    all    all    ::1/128    scram-sha-256" | sudo tee -a "$conf_dir/pg_hba.conf" > /dev/null
  sudo grep -q "127.0.0.1/32" "$conf_dir/pg_hba.conf" || echo "host    all    all    127.0.0.1/32    scram-sha-256" | sudo tee -a "$conf_dir/pg_hba.conf" > /dev/null

  grep -q "host replication replicator 127.0.0.1/32 scram-sha-256" "$conf_dir/pg_hba.conf" || \
  echo -e "\nhost replication replicator 127.0.0.1/32 scram-sha-256" | sudo tee -a "$conf_dir/pg_hba.conf" > /dev/null

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

verify_postgres_password() {
  echo "[*] Verifying postgres password..."
  if PGPASSWORD="$POSTGRES_PW" psql -U postgres -h 127.0.0.1 -p 5432 -c "SELECT current_user;" &>/dev/null; then
    echo "[+] Password verified. Connection successful."
  else
    echo "[!] Connection failed. Invalid password or PostgreSQL not ready."
    exit 1
  fi
}

setup_replica() {
  echo "=== 🛰️ Setting up replica node ==="
  sudo apt update && sudo apt install -y postgresql

  detect_pg_version
  ensure_postgres_user
  prompt_master_ip
  prompt_postgres_password
  prompt_replicator_password
  prompt_replica_identity

  clean_broken_cluster
  ensure_cluster_exists

  echo "[*] Stopping PostgreSQL and cleaning data directory..."
  sudo systemctl stop postgresql@$PG_VERSION-main
  sudo -u postgres rm -rf "$DATA_DIR"

  echo "[*] Performing base backup from master ($MASTER_IP)..."
  sudo -u postgres PGPASSWORD="$REPL_PASS" pg_basebackup -h "$MASTER_IP" -D "$DATA_DIR" -U replicator -P

  apply_config_files
  fix_pg_hba_auth
  wait_for_postgres
  verify_postgres_password

  echo "[✓] Replica setup complete."
  unset REPL_PASS
}

setup_replica