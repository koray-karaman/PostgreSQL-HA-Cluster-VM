#!/bin/bash


PGHA_DIR="$(cd "$(dirname "$0")" && pwd)"
PGHA_CONFIG="/etc/pg_ha.conf"
CONFIG_DIR="$PGHA_DIR/configs"
PG_VERSION=""
DATA_DIR=""
cd /tmp || true
detect_pg_version() {
  PG_VERSION=$(psql -V | awk '{print $3}' | cut -d. -f1)
  DATA_DIR="/var/lib/postgresql/$PG_VERSION/main"
}

collect_node_config() {
  echo "🧠 Starting PostgreSQL HA configuration..."

  echo "🌐 MASTER NODE Information:"
  read -p "  ➤ Master IP address: " MASTER_IP
  read -p "  ➤ Master name: " MASTER_NAME

  echo "📡 REPLICA 1 Information:"
  read -p "  ➤ Replica 1 IP address: " REPL1_IP
  read -p "  ➤ Replica 1 name: " REPL1_NAME

  echo "📡 REPLICA 2 Information:"
  read -p "  ➤ Replica 2 IP address: " REPL2_IP
  read -p "  ➤ Replica 2 name: " REPL2_NAME

  echo "🔐 Passwords:"
  read -s -p "  ➤ Password for 'postgres' user: " POSTGRES_PW
  echo
  read -s -p "  ➤ Password for 'replicator' user: " REPL_PASS
  echo

  echo "📦 Saving configuration to → $PGHA_CONFIG"
  sudo tee "$PGHA_CONFIG" > /dev/null <<EOF
master_name=$MASTER_NAME
master_ip=$MASTER_IP
replica1_name=$REPL1_NAME
replica1_ip=$REPL1_IP
replica2_name=$REPL2_NAME
replica2_ip=$REPL2_IP
postgres_pw=$POSTGRES_PW
replicator_pw=$REPL_PASS
EOF
}

clean_broken_cluster() {
  echo "[*] Cleaning any existing cluster..."
  sudo pg_dropcluster $PG_VERSION main --stop 2>/dev/null || true
  sudo rm -rf /etc/postgresql/$PG_VERSION/main "$DATA_DIR"
}

ensure_postgres_user() {
  if ! id "postgres" &>/dev/null; then
    echo "[*] Creating system user 'postgres'..."
    sudo adduser --system --group --home /var/lib/postgresql postgres
  fi
}

ensure_cluster_exists() {
  echo "[*] Creating PostgreSQL cluster..."
  sudo pg_createcluster "$PG_VERSION" main --start
}

apply_config_files() {
  echo "[*] Applying PostgreSQL configuration..."
  local conf_dir="/etc/postgresql/$PG_VERSION/main"

  sudo cp "$CONFIG_DIR/postgresql.conf" "$conf_dir/postgresql.conf"
  sudo cp "$CONFIG_DIR/pg_hba.conf" "$conf_dir/pg_hba.conf"

  sudo sed -i '/^data_directory\s*=.*/d' "$conf_dir/postgresql.conf"
  echo "data_directory = '$DATA_DIR'" | sudo tee -a "$conf_dir/postgresql.conf" > /dev/null
}

append_pg_hba_for_nodes() {
  local hba="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
  echo "[*] Adding pg_hba.conf access rules..."

  for ip in "$replica1_ip" "$replica2_ip"; do
    echo "host    all    postgres    $ip/32    scram-sha-256" | sudo tee -a "$hba" > /dev/null
    echo "host    replication    replicator    $ip/32    scram-sha-256" | sudo tee -a "$hba" > /dev/null
  done
}

configure_sync_standby_names() {
  local conf="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
  echo "[*] Configuring synchronous_standby_names..."
  sudo sed -i "/^synchronous_standby_names/d" "$conf"
  echo "synchronous_standby_names = 'FIRST 1 ($replica1_name, $replica2_name)'" | sudo tee -a "$conf" > /dev/null
}

fix_pg_hba_auth() {
  local hba="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
  echo "[*] Switching peer auth to md5..."
  sudo sed -i 's/^local\s\+all\s\+postgres\s\+peer/local all postgres md5/' "$hba"
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

disable_sync_replication() {
  local conf="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
  echo "[*] Temporarily disabling synchronous replication..."
  sudo sed -i "s/^synchronous_standby_names.*/synchronous_standby_names = ''/" "$conf" || echo "synchronous_standby_names = ''" | sudo tee -a "$conf" > /dev/null
}

restore_sync_replication() {
  configure_sync_standby_names
}

set_postgres_password() {
  echo "[*] Setting password for postgres..."
  sudo -u postgres psql -p 5432 <<EOF
SET synchronous_commit = off;
ALTER USER postgres WITH PASSWORD '$postgres_pw';
EOF
}

create_replication_user() {
  echo "[*] Creating or updating replicator role..."
  sudo -u postgres psql -p 5432 <<EOF
SET synchronous_commit = off;
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'replicator') THEN
      CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '$replicator_pw';
   ELSE
      ALTER ROLE replicator WITH PASSWORD '$replicator_pw';
   END IF;
END
\$\$;
EOF
}

verify_connection() {
  echo "[*] Verifying local connection..."
  PGPASSWORD="$postgres_pw" psql -U postgres -h 127.0.0.1 -p 5432 -c "SELECT current_user, inet_server_addr;" || {
    echo "[!] Connection failed."
    exit 1
  }
  echo "[+] Connection successful."
}

reset_pg_ha_config() {
  local config_path="/etc/pg_ha.conf"
  if [ -f "$config_path" ]; then
    echo "[*] Removing existing pg_ha.conf configuration..."
    sudo rm -f "$config_path"
  fi
}

setup_master() {
  echo "=== 🚀 MASTER NODE SETUP STARTING ==="
  sudo apt update && sudo apt install -y postgresql postgresql-contrib
  reset_pg_ha_config
  detect_pg_version
  clean_broken_cluster
  ensure_postgres_user
  collect_node_config
  source "$PGHA_CONFIG"

  ensure_cluster_exists
  apply_config_files
  append_pg_hba_for_nodes
  configure_sync_standby_names
  fix_pg_hba_auth
  sudo systemctl restart postgresql@$PG_VERSION-main
  wait_for_postgres

  disable_sync_replication
  set_postgres_password
  create_replication_user
  restore_sync_replication
  sudo systemctl restart postgresql@$PG_VERSION-main
  verify_connection

  echo -e "\n✅ Master setup complete."
  echo "🔑 Use this password in replica setup: $replicator_pw"
  unset replicator_pw
}

setup_master