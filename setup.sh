#!/bin/bash
ROLE="$1"
MASTER_IP="$2"
PGHA_DIR="$(cd "$(dirname "$0")" && pwd)"
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

create_replication_user() {
  echo "[*] Creating replication user..."
  sudo -u postgres /usr/lib/postgresql/$PG_VERSION/bin/psql -p 5432 -c "CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'replicator';"
}

verify_connection() {
  echo "[*] Verifying connection..."
  PGPASSWORD="$POSTGRES_PW" psql -U postgres -h localhost -p 5432 -c "SELECT current_user, inet_server_addr();" || {
    echo "[!] Connection failed."
    exit 1
  }
  echo "[+] Connection verified."
}

setup_master() {
  echo "=== Setting up master node ==="
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

  echo "[✓] Master setup complete."
}

setup_replica() {
  echo "=== Setting up replica node ==="
  if [ -z "$MASTER_IP" ]; then
    echo "[!] Master IP not provided."
    exit 1
  fi

  sudo apt update && sudo apt install -y postgresql

  detect_pg_version
  ensure_postgres_user
  prompt_postgres_password
  clean_broken_cluster
  ensure_cluster_exists

  echo "[*] Cleaning data directory..."
  sudo systemctl stop postgresql@$PG_VERSION-main
  sudo -u postgres rm -rf "$DATA_DIR"

  echo "[*] Performing base backup from master..."
  sudo -u postgres pg_basebackup -h "$MASTER_IP" -D "$DATA_DIR" -U replicator -P -R

  apply_config_files
  fix_pg_hba_auth
  wait_for_postgres
  set_postgres_password
  verify_connection

  echo "[✓] Replica setup complete."
}

setup_pgpool() {
  echo "=== Setting up pgpool node ==="
  sudo apt update && sudo apt install -y pgpool2
  echo "[✓] Pgpool installed."
}

setup_pgha() {
  echo "=== Setting up keepalived node ==="
  sudo apt update && sudo apt install -y keepalived
  echo "[✓] Keepalived installed."
}

setup_monitoring() {
  echo "=== Setting up monitoring node ==="
  sudo apt update && sudo apt install -y prometheus grafana
  echo "[✓] Monitoring stack installed."
}

case "$ROLE" in
  master) setup_master ;;
  replica) setup_replica ;;
  pgpool) setup_pgpool ;;
  pgha) setup_pgha ;;
  monitoring) setup_monitoring ;;
  *)
    echo "[!] Unknown role: $ROLE"
    echo "Valid roles: master, replica, pgpool, pgha, monitoring"
    exit 1
    ;;
esac