#!/bin/bash

PGHA_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$PGHA_DIR/scripts"
CONFIGS_DIR="$PGHA_DIR/configs"

echo "[*] Preparing environment..."

# Create folders
mkdir -p "$SCRIPTS_DIR" "$CONFIGS_DIR"

# Download configs
echo "[*] Downloading configuration files..."
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/postgresql.conf -O "$CONFIGS_DIR/postgresql.conf"
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pg_hba.conf -O "$CONFIGS_DIR/pg_hba.conf"

# Download role scripts
echo "[*] Downloading role-based setup scripts..."
for script in setup_master.sh setup_replica.sh setup_pgpool.sh setup_pgha.sh setup_monitoring.sh; do
  wget -q "https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/scripts/$script" -O "$SCRIPTS_DIR/$script"
  chmod +x "$SCRIPTS_DIR/$script"
done


verify_downloads() {
  local missing=0

  # Check config files
  for file in postgresql.conf pg_hba.conf; do
    if [ ! -f "$CONFIGS_DIR/$file" ]; then
      echo "[!] Missing config file: $file"
      missing=1
    fi
  done

  # Check script files
  for script in setup_master.sh setup_replica.sh setup_pgpool.sh setup_pgha.sh setup_monitoring.sh; do
    if [ ! -f "$SCRIPTS_DIR/$script" ]; then
      echo "[!] Missing script file: $script"
      missing=1
    fi
  done

  if [ "$missing" -eq 1 ]; then
    echo "[✗] One or more required files are missing. Setup aborted."
    exit 1
  fi
}


verify_downloads
echo "[+] Environment ready."

# Prompt user for role
echo ""
echo "📦 Select node role to configure:"
echo "  1 → pg_master"
echo "  2 → pg_replica_1"
echo "  3 → pg_replica_2"
echo "  4 → pgpool"
echo "  5 → pgha"
echo "  6 → monitoring"
echo ""
read -p "Enter choice [1-6]: " CHOICE

case "$CHOICE" in
  1)
    ROLE="pg_master"
    bash "$SCRIPTS_DIR/setup_master.sh"
    ;;
  2|3)
    ROLE="pg_replica"
    read -p "Enter MASTER IP address: " MASTER_IP
    bash "$SCRIPTS_DIR/setup_replica.sh" "$MASTER_IP"
    ;;
  4)
    ROLE="pgpool"
    bash "$SCRIPTS_DIR/setup_pgpool.sh"
    ;;
  5)
    ROLE="pgha"
    bash "$SCRIPTS_DIR/setup_pgha.sh"
    ;;
  6)
    ROLE="monitoring"
    bash "$SCRIPTS_DIR/setup_monitoring.sh"
    ;;
  *)
    echo "[!] Invalid choice. Aborting."
    exit 1
    ;;
esac

echo "[✓] Setup completed for role: $ROLE"

