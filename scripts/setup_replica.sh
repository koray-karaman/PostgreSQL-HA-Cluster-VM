#!/bin/bash
cd /tmp || true

PGHA_CONFIG="/etc/pg_ha.conf"
PGHA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$PGHA_DIR/configs"
PG_VERSION=""
DATA_DIR=""

detect_pg_version() {
  PG_VERSION=$(psql -V | awk '{print $3}' | cut -d. -f1)
  DATA_DIR="/var/lib/postgresql/$PG_VERSION/main"
}

collect_replica_config() {
  echo "🧠 Starting PostgreSQL Replica Configuration..."

  read -p "  ➤ Replica node name (e.g. pg_replica1): " SELF_NAME
  read -p "  ➤ This node's IP address: " SELF_IP
  read -p "  ➤ Master IP address: " MASTER_IP
  read -s -p "  ➤ Password for PostgreSQL 'postgres' user: " POSTGRES_PW
  echo
  read -s -p "  ➤ Password for replication user 'replicator': " REPL_PASS
  echo

  echo "📦 Saving configuration to → $PGHA_CONFIG"
  sudo tee "$PGHA_CONFIG" > /dev/null <<EOF
self_name=$SELF_NAME
self_ip=$SELF_IP
master_ip=$MASTER_IP
postgres_pw=$POSTGRES_PW
replicator_pw=$REPL_PASS
EOF
}

ensure_postgres_user() {
  if ! id "postgres" &>/dev/null; then
    echo "[*] Creating 'postgres' system user..."
    sudo adduser --system --group --home /var/lib/postgresql postgres
    echo "[+] 'postgres' user created."
  fi
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

perform_base_backup() {
  echo "[*] Stopping PostgreSQL and cleaning data directory..."
  sudo systemctl stop postgresql@$PG_VERSION-main
  sudo -u postgres rm -rf "$DATA_DIR"

  echo "[*] Performing base backup from master ($master_ip)..."
  sudo -u postgres PGPASSWORD="$replicator_pw" pg_basebackup -h "$master_ip" -D "$DATA_DIR" -U replicator -P
}

set_primary_conninfo() {
  local conf="/etc/postgresql/$PG_VERSION/main/postgresql.auto.conf"
  echo "[*] Setting primary_conninfo with application_name..."
  echo "primary_conninfo = 'host=$master_ip port=5432 user=replicator password=$replicator_pw application_name=$self_name'" | sudo tee "$conf" > /dev/null
}

apply_config_files() {
  echo "[*] Applying PostgreSQL configuration..."
  local conf_dir="/etc/postgresql/$PG_VERSION/main"

  sudo cp "$CONFIG_DIR/postgresql.conf" "$conf_dir/postgresql.conf"
  sudo cp "$CONFIG_DIR/pg_hba.conf" "$conf_dir/pg_hba.conf"

  sudo sed -i '/^data_directory\s*=.*/d' "$conf_dir/postgresql.conf"
  echo "data_directory = '$DATA_DIR'" | sudo tee -a "$conf_dir/postgresql.conf" > /dev/null

  sudo grep -q "::1/128" "$conf_dir/pg_hba.conf" || echo "host    all    all    ::1/128    scram-sha-256" | sudo tee -a "$conf_dir/pg_hba.conf" > /dev/null
  sudo grep -q "127.0.0.1/32" "$conf_dir/pg_hba.conf" || echo "host    all    all    127.0.0.1/32    scram-sha-256" | sudo tee -a "$conf_dir/pg_hba.conf" > /dev/null

  grep -q "host replication replicator 127.0.0.1/32 scram-sha-256" "$conf_dir/pg_hba.conf" || \
  echo "host replication replicator 127.0.0.1/32 scram-sha-256" | sudo tee -a "$conf_dir/pg_hba.conf" > /dev/null

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
    fi
    sleep 1
  done
  echo "[!] PostgreSQL did not become ready in time. Aborting."
  exit 1
}

verify_postgres_password() {
  echo "[*] Verifying postgres password..."
  if PGPASSWORD="$postgres_pw" psql -U postgres -h 127.0.0.1 -p 5432 -c "SELECT current_user;" &>/dev/null; then
    echo "[+] Password verified. Connection successful."
  else
    echo "[!] Connection failed. Invalid password or PostgreSQL not ready."
    exit 1
  fi
}

setup_replica() {
  echo "=== 🛰️ REPLICA NODE SETUP STARTING ==="
  sudo apt update && sudo apt install -y postgresql

  detect_pg_version
  ensure_postgres_user
  collect_replica_config
  source "$PGHA_CONFIG"

  clean_broken_cluster
  ensure_cluster_exists
  perform_base_backup
  set_primary_conninfo
  apply_config_files
  fix_pg_hba_auth
  wait_for_postgres
  verify_postgres_password

  echo -e "\n✅ Replica setup complete."
  unset replicator_pw
}

setup_replica