# PostgreSQL HA Cluster on Virtual Machines

A fully automated setup for a PostgreSQL High Availability cluster using Ubuntu Server VMs.  
This project creates a resilient PostgreSQL cluster with primary and replica nodes, managed by Pgpool and HAProxy, and monitored via Prometheus + Grafana.

## Why this project?

This repo is for anyone who:

- Tried Docker and got stuck in permission hell
- Wants full control over PostgreSQL configuration
- Prefers VM-based setups for clarity and stability
- Believes in sharing working solutions with others

## Cluster Architecture

This setup builds a PostgreSQL cluster optimized for high availability and failover:

- `pg-master`: Primary node (formerly known as master)
- `pg-replica1`, `pg-replica2`: Standby nodes (formerly known as slaves)
- `pgpool-node`: Connection manager and load balancer
- `pgha-node`: HA controller (Pgpool watchdog + VIP management)
- `monitoring-node`: Prometheus + Grafana dashboard

The architecture supports streaming replication, automatic failover, and load balancing.

## Replication Setup

This project supports setting up a PostgreSQL High Availability cluster using either:

- **Primary/Replica architecture** (recommended terminology)
- **Master/Slave architecture** (legacy naming, still widely used)

The `setup.sh` script can initialize both primary and replica nodes with streaming replication.  
Each replica node continuously follows the primary and can be promoted in case of failure.

## Network Setup

To avoid IP conflicts and SSH disconnections, each VM should have a static IP.  
Use the `configs/network-setup.yaml` file as a reference and apply it with:

```bash
sudo cp configs/network-setup.yaml /etc/netplan/00-installer-config.yaml
sudo netplan apply
```

> ⚠️ **Warning:** Do not run `ip addr flush` on a VM accessed via SSH.  
> It will remove the IP and disconnect your session. Use `netplan apply` instead.

## Monitoring & Dashboard

This project includes Prometheus + Grafana integration for real-time cluster monitoring.

- PostgreSQL Exporter exposes metrics on port `9187`
- Prometheus scrapes metrics every 10 seconds
- Grafana visualizes replication lag, active connections, failover events

To set it up:

```bash
cd monitoring
bash postgres_exporter_setup.sh
```

Then start Prometheus and Grafana using your preferred method (systemd, Docker, etc).  
Import `grafana-dashboards.json` into Grafana to get started.

📦 See `monitoring/` folder for configuration files and setup scripts.

## Project Structure

```text
postgres-ha-cluster-vm/
├── setup.sh                      # Automates PostgreSQL node setup
├── healthcheck.sh                # PostgreSQL status & role checker
├── configs/                      # Configuration files
│   ├── postgresql.conf
│   ├── pg_hba.conf
│   ├── network-setup.yaml
│   ├── pgpool-healthcheck.conf
├── monitoring/                   # Dashboard & metrics
│   ├── prometheus.yml
│   ├── postgres_exporter_setup.sh
│   ├── grafana-dashboards.json
│   └── README.md
├── README.md                     # Project documentation
├── LICENSE                       # MIT license
└── .gitignore                    # Excludes unnecessary files
```

## Cluster Node Layout

```text
6 Virtual Machines — each with a dedicated role:

1. pg-master         → Primary PostgreSQL node (handles writes)
2. pg-replica1       → Standby node (streaming replication)
3. pg-replica2       → Additional standby node for failover
4. pgpool-node       → Connection manager (load balancing + healthcheck)
5. pgha-node         → HA controller (Pgpool watchdog + VIP management)
6. monitoring-node   → Prometheus + Grafana dashboard
```

> Pgpool and PGHA are intentionally separated for better fault isolation and observability.

## License

This project is licensed under the MIT License.  
Feel free to use, modify, and share it. If it helps you, star it. If it helps others, fork it.

---

Built by [Koray](https://github.com/koray-karaman) — for clarity, control, and community.
