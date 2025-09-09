#!/bin/bash
cd /tmp || true

ROLE="$1"
MASTER_IP="$2"
PGHA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$PGHA_DIR/configs"
PG_VERSION=""
DATA_DIR=""
REPL_PASS=""
POSTGRES_PW=""

# Detect PostgreSQL major version and data directory
detect_pg_version() {
  PG_VERSION=$(psql -V | awk '{print $3}' | cut -d. -f1)
  DATA_DIR="/var/lib/postgresql/$PG_VERSION/main"
}

# Ensure postgres system user exists
ensure_postgres_user() {
  if ! id "postgres" &>/dev/null; then
    echo "[*] Creating 'postgres' system user..."
    sudo adduser --system --group --home /var/lib/postgresql postgres
    echo "[+] 'postgres' user created."
  fi
}

# Prompt for postgres password
prompt_postgres_password() {
  echo -n "🔐 Enter password for PostgreSQL 'postgres' user: "
  read -s POSTGRES_PW
  echo
}

# Prompt for replicator password
prompt_replicator_password() {
  echo -n "🔐 Enter password for replication user 'replicator': "
  read -s REPL_PASS
  echo
}

# Drop broken cluster and clean data directory
clean_broken_cluster() {
  echo "[*] Cleaning broken cluster if exists..."
  sudo pg_dropcluster $PG_VERSION main --stop 2>/dev/null || true
  sudo rm -rf /etc/postgresql/$PG_VERSION/main "$DATA_DIR"
}

# Create new PostgreSQL cluster
ensure_cluster_exists() {
  echo "[*] Creating PostgreSQL $PG_VERSION cluster..."
  sudo pg_createcluster "$PG_VERSION" main --start
}

# Apply custom configuration files
apply_config_files() {
  echo "[*] Applying PostgreSQL configuration..."
  sudo chown postgres:postgres "$conf_dir/pg_hba.conf"
  local conf_dir="/etc/postgresql/$PG_VERSION/main"

  sudo cp "$CONFIG_DIR/postgresql.conf" "$conf_dir/postgresql.conf"
  sudo cp "$CONFIG_DIR/pg_hba.conf" "$conf_dir/pg_hba.conf"

  # Explicit data directory for HA setup
  sudo sed -i '/^data_directory\s*=.*/d' "$conf_dir/postgresql.conf"
  echo -e "\n# Explicit data directory for HA setup\ndata_directory = '$DATA_DIR'" | sudo tee -a "$conf_dir/postgresql.conf" > /dev/null

  # Ensure localhost access is allowed
  sudo grep -q "::1/128" "$conf_dir/pg_hba.conf" || echo "host    all    all    ::1/128    scram-sha-256" | sudo tee -a "$conf_dir/pg_hba.conf" > /dev/null
  sudo grep -q "127.0.0.1/32" "$conf_dir/pg_hba.conf" || echo "host    all    all    127.0.0.1/32    scram-sha-256" | sudo tee -a "$conf_dir/pg_hba.conf" > /dev/null

  # Add replication access for replicas (with newline to avoid merge errors)
  sudo grep -q "host replication replicator 192.168.56.0/24 scram-sha-256" "$conf_dir/pg_hba.conf" || \
  echo -e "\nhost replication replicator 192.168.56.0/24 scram-sha-256" | sudo tee -a "$conf_dir/pg_hba.conf" > /dev/null

  sudo systemctl restart postgresql@$PG_VERSION-main
  echo "[+] Configuration applied."
}

# Switch peer auth to md5 for local postgres login
fix_pg_hba_auth() {
  local hba="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
  echo "[*] Switching peer auth to md5..."
  sudo sed -i 's/^local\s\+all\s\+postgres\s\+peer/local all postgres md5/' "$hba"
  sudo systemctl restart postgresql@$PG_VERSION-main
}

# Wait until PostgreSQL is ready
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

# Set password for postgres user
set_postgres_password() {
  echo "[*] Setting password for postgres..."
  sudo -u postgres /usr/lib/postgresql/$PG_VERSION/bin/psql -p 5432 -c "ALTER USER postgres WITH PASSWORD '$POSTGRES_PW';"
}

# Create or update replication user
create_replication_user() {
  echo "[*] Creating or updating replication user..."
  sudo -u postgres psql -p 5432 <<EOF
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'replicator') THEN
      CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '$REPL_PASS';
   ELSE
      ALTER ROLE replicator WITH PASSWORD '$REPL_PASS';
   END IF;
END
\$\$;
EOF
}

# Verify local connection
verify_connection() {
  echo "[*] Verifying connection..."
  PGPASSWORD="$POSTGRES_PW" psql -U postgres -h 127.0.0.1 -p 5432 -c "SELECT current_user, inet_server_addr();" || {
    echo "[!] Connection failed."
    exit 1
  }
  echo "[+] Connection verified."
}

# Main setup function
setup_master() {
  echo "=== 🚀 Setting up master node ==="
  sudo apt update && sudo apt install -y postgresql postgresql-contrib

  detect_pg_version
  clean_broken_cluster
  ensure_postgres_user
  prompt_postgres_password
  prompt_replicator_password
  ensure_cluster_exists
  apply_config_files
  fix_pg_hba_auth
  wait_for_postgres
  set_postgres_password
  create_replication_user
  verify_connection

  echo -e "\n✅ Master setup complete."
  echo "🔑 Use this password in replica setup: $REPL_PASS"
  unset REPL_PASS
}

setup_master