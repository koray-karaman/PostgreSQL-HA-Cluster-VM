#!/bin/bash
# PostgreSQL Exporter Setup Script

EXPORTER_VERSION="0.15.0"

echo "[*] Installing PostgreSQL Exporter..."
wget https://github.com/prometheus-community/postgres_exporter/releases/download/v${EXPORTER_VERSION}/postgres_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz
tar -xzf postgres_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz
sudo mv postgres_exporter /usr/local/bin/

echo "[*] Creating exporter user..."
sudo -u postgres psql -c "CREATE USER exporter WITH PASSWORD 'exporter_pass';"
sudo -u postgres psql -c "GRANT CONNECT ON DATABASE postgres TO exporter;"
sudo -u postgres psql -c "GRANT USAGE ON SCHEMA pg_catalog TO exporter;"
sudo -u postgres psql -c "GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog TO exporter;"

echo "[*] Starting exporter..."
nohup postgres_exporter --web.listen-address=":9187" --extend.query-path=monitoring/queries.yaml &