#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "[!] Please run this script with sudo."
  exit 1
fi

# Ensure 'postgres' system user exists
if ! id "postgres" &>/dev/null; then
  echo "[*] Creating system user 'postgres'..."
  sudo adduser --system --group --home /var/lib/postgresql postgres
fi

# Switch to postgres user for all PostgreSQL operations
echo "[*] Switching user 'postgres'..."
sudo -u postgres bash <<'EOF'

# Collect configuration details interactively
echo "🧠 Starting PostgreSQL HA configuration..."

read -p "  ➤ Master IP address: " MASTER_IP
read -p "  ➤ Master name: " MASTER_NAME

read -p "  ➤ Replica 1 IP address: " REPL1_IP
read -p "  ➤ Replica 1 name: " REPL1_NAME

read -p "  ➤ Replica 2 IP address: " REPL2_IP
read -p "  ➤ Replica 2 name: " REPL2_NAME

read -s -p "  ➤ Password for 'postgres' user: " POSTGRES_PW
echo
read -s -p "  ➤ Password for 'replicator' user: " REPL_PASS
echo

# Detect installed PostgreSQL version and set data/config directories
PG_VERSION=$(psql -V | awk '{print $3}' | cut -d. -f1)
DATA_DIR="/var/lib/postgresql/$PG_VERSION/main"
CONF_DIR="/etc/postgresql/$PG_VERSION/main"

# Remove any existing cluster and configuration
echo "[*] Cleaning any existing cluster..."
pg_dropcluster $PG_VERSION main --stop 2>/dev/null || true
rm -rf "$CONF_DIR" "$DATA_DIR"

# Create a new PostgreSQL cluster
echo "[*] Creating PostgreSQL cluster..."
pg_createcluster "$PG_VERSION" main

# Apply custom configuration files
echo "[*] Applying configuration files..."
cp ~/pg-ha/configs/postgresql.conf "$CONF_DIR/postgresql.conf"
cp ~/pg-ha/configs/pg_hba.conf "$CONF_DIR/pg_hba.conf"

# Set the correct data directory
sed -i '/^data_directory\s*=.*/d' "$CONF_DIR/postgresql.conf"
echo "data_directory = '$DATA_DIR'" >> "$CONF_DIR/postgresql.conf"

# Ensure localhost access is allowed
grep -q "::1/128" "$CONF_DIR/pg_hba.conf" || echo "host all all ::1/128 scram-sha-256" >> "$CONF_DIR/pg_hba.conf"
grep -q "127.0.0.1/32" "$CONF_DIR/pg_hba.conf" || echo "host all all 127.0.0.1/32 scram-sha-256" >> "$CONF_DIR/pg_hba.conf"

# Add access rules for replica nodes
echo "[*] Adding pg_hba.conf access rules..."
for ip in "$REPL1_IP" "$REPL2_IP"; do
  echo "host all postgres $ip/32 scram-sha-256" >> "$CONF_DIR/pg_hba.conf"
  echo "host replication replicator $ip/32 scram-sha-256" >> "$CONF_DIR/pg_hba.conf"
done

# Configure synchronous replication settings
echo "[*] Configuring synchronous_standby_names..."
sed -i "/^synchronous_standby_names/d" "$CONF_DIR/postgresql.conf"
echo "synchronous_standby_names = 'FIRST 1 ($REPL1_NAME, $REPL2_NAME)'" >> "$CONF_DIR/postgresql.conf"

# Change local authentication method from peer to md5
echo "[*] Switching peer auth to md5..."
sed -i 's/^local\s\+all\s\+postgres\s\+peer/local all postgres md5/' "$CONF_DIR/pg_hba.conf"

# Restart PostgreSQL to apply changes
echo "[*] Restarting PostgreSQL service..."
systemctl restart postgresql@$PG_VERSION-main

# Wait until PostgreSQL is ready to accept connections
echo "[*] Waiting for PostgreSQL to become available..."
for i in {1..30}; do
  if /usr/lib/postgresql/$PG_VERSION/bin/psql -p 5432 -c "SELECT 1;" &>/dev/null; then
    echo "[+] PostgreSQL is ready after $i seconds."
    break
  fi
  sleep 1
done

# Temporarily disable synchronous replication for initial setup
echo "[*] Temporarily disabling synchronous replication..."
sed -i "s/^synchronous_standby_names.*/synchronous_standby_names = ''/" "$CONF_DIR/postgresql.conf"
systemctl restart postgresql@$PG_VERSION-main

# Set password for the 'postgres' user
echo "[*] Setting password for postgres..."
psql -p 5432 <<EOSQL
SET synchronous_commit = off;
ALTER USER postgres WITH PASSWORD '$POSTGRES_PW';
EOSQL

# Create or update the 'replicator' role for streaming replication
echo "[*] Creating or updating replicator role..."
psql -p 5432 <<EOSQL
SET synchronous_commit = off;
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'replicator') THEN
      CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '$REPL_PASS';
   ELSE
      ALTER ROLE replicator WITH PASSWORD '$REPL_PASS';
   END IF;
END
\$\$;
EOSQL

# Restore synchronous replication settings
echo "[*] Restoring synchronous replication..."
sed -i "/^synchronous_standby_names/d" "$CONF_DIR/postgresql.conf"
echo "synchronous_standby_names = 'FIRST 1 ($REPL1_NAME, $REPL2_NAME)'" >> "$CONF_DIR/postgresql.conf"
systemctl restart postgresql@$PG_VERSION-main

# Verify local connection
echo "[*] Verifying local connection..."
PGPASSWORD="$POSTGRES_PW" psql -U postgres -h 127.0.0.1 -p 5432 -c "SELECT current_user, inet_server_addr;" || {
  echo "[!] Connection failed."
  exit 1
}

# Final message
echo -e "\n✅ Master setup complete."
echo "🔑 Use this password in replica setup: $REPL_PASS"

EOF
