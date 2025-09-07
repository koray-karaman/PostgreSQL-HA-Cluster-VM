# Monitoring Setup

This folder contains configuration files for Prometheus + Grafana integration.

## Components

- **prometheus.yml** → Prometheus scrape configuration
- **postgres_exporter_setup.sh** → Installs and configures PostgreSQL Exporter
- **queries.yaml** → Custom queries for replication status and lag
- **grafana-dashboards.json** → Prebuilt Grafana dashboard

## Usage

1. Run `postgres_exporter_setup.sh` on each PostgreSQL node.
2. Start Prometheus with `prometheus.yml`.
3. Import `grafana-dashboards.json` into Grafana.
4. View metrics such as:
   - PostgreSQL availability
   - Node role (Primary / Replica)
   - Replication lag
   - Connection counts