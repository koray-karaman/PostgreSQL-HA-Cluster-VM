#!/bin/bash

echo "🧠 Starting Pgpool-II full HA setup..."

# Prompt for node details
read -p "  ➤ Master IP address: " MASTER_IP
read -p "  ➤ Replica 1 IP address: " REPL1_IP
read -p "  ➤ Replica 2 IP address: " REPL2_IP
read -p "  ➤ Pgpool node hostname: " PGPOOL_HOSTNAME
read -p "  ➤ Virtual IP for failover (watchdog): " VIRTUAL_IP

read -p "  ➤ PostgreSQL username: " PG_USER
read -s -p "  ➤ PostgreSQL password: " PG_PASS
echo

# Install Pgpool-II and repmgr
sudo apt update
sudo apt install -y pgpool2 repmgr

# Define config paths
PGPOOL_CONF="/etc/pgpool2/pgpool.conf"
HEALTHCHECK_CONF="/etc/pgpool2/pgpool-healthcheck.conf"
PCP_CONF="/etc/pgpool2/pcp.conf"
FAILOVER_SCRIPT="/etc/pgpool2/failover.sh"

# Download templates from GitHub
wget -O "$PGPOOL_CONF" https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pgpool.conf
wget -O "$HEALTHCHECK_CONF" https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pgpool-healthcheck.conf
wget -O "$FAILOVER_SCRIPT" https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/scripts/failover.sh
wget -O "$PCP_CONF" https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pcp.conf

# Make failover script executable and assign to postgres
sudo chmod +x "$FAILOVER_SCRIPT"
sudo chown postgres:postgres "$FAILOVER_SCRIPT"

# Replace placeholders in pgpool.conf
sudo sed -i "s/{{MASTER_IP}}/$MASTER_IP/g" "$PGPOOL_CONF"
sudo sed -i "s/{{REPL1_IP}}/$REPL1_IP/g" "$PGPOOL_CONF"
sudo sed -i "s/{{REPL2_IP}}/$REPL2_IP/g" "$PGPOOL_CONF"
sudo sed -i "s/{{PG_USER}}/$PG_USER/g" "$PGPOOL_CONF"
sudo sed -i "s/{{PG_PASS}}/$PG_PASS/g" "$PGPOOL_CONF"
sudo sed -i "s/{{PGPOOL_HOSTNAME}}/$PGPOOL_HOSTNAME/g" "$PGPOOL_CONF"
sudo sed -i "s/{{VIRTUAL_IP}}/$VIRTUAL_IP/g" "$PGPOOL_CONF"

# Replace placeholders in healthcheck.conf
sudo sed -i "s/{{PG_USER}}/$PG_USER/g" "$HEALTHCHECK_CONF"
sudo sed -i "s/{{PG_PASS}}/$PG_PASS/g" "$HEALTHCHECK_CONF"

# Generate PCP user entry
PG_MD5_PASS=$(pg_md5 "$PG_PASS")
sudo sed -i "s/{{PG_USER}}/$PG_USER/g" "$PCP_CONF"
sudo sed -i "s/{{PG_MD5_PASS}}/$PG_MD5_PASS/g" "$PCP_CONF"

# Enable watchdog and load balancing in pgpool.conf
sudo sed -i "s/^use_watchdog = off/use_watchdog = on/" "$PGPOOL_CONF"
sudo sed -i "s/^load_balance_mode = off/load_balance_mode = on/" "$PGPOOL_CONF"

# Restart Pgpool-II
sudo systemctl restart pgpool2
echo "✅ Pgpool-II full HA setup complete."
