"# 🚀 PostgreSQL High Availability Cluster on Ubuntu VMs

**Automated, Resilient, and Transparent PostgreSQL HA Setup—No Docker, Full Control**

Welcome to the official repository for **PostgreSQL-HA-Cluster-VM**, an open-source project that provides a fully automated setup for a PostgreSQL High Availability (HA) cluster using Ubuntu Server virtual machines. This project is ideal for developers, DevOps engineers, and system architects who want a clean, Docker-free PostgreSQL HA environment with full visibility and control over every component.

> ⚠️ **Project Status:** Actively maintained and evolving  
> 📄 **License:** MIT License — Free to use, modify, and distribute



## 🌟 Key Features

- ✅ **Automated Setup**: One script to configure primary, replica, Pgpool, HA controller, and monitoring nodes  
- 🧩 **Modular Architecture**: Clean separation of roles across VMs for scalability and clarity  
- 🔍 **Monitoring & Alerts**: Integrated Prometheus + Grafana dashboards with replication lag alerts  
- 🛠️ **Failover Scenarios**: Supports planned and unplanned failover with recovery steps  
- 🔐 **No Docker Dependency**: Native Ubuntu installation for full control and transparency  
- 📊 **Post-Install Verification**: Built-in health checks and validation scripts  


## 📦 Project Structure

```
PostgreSQL-HA-Cluster-VM/
├── setup.sh                  # Main setup script for all node roles
├── healthcheck.sh            # Health check script for DB nodes
├── verify.sh                 # Post-install verification script
├── configs/                  # Configuration files for PostgreSQL, Pgpool, networking
│   ├── postgresql.conf
│   ├── pg_hba.conf
│   ├── pgpool.conf
│   ├── watchdog.conf
│   └── network-setup.yaml
├── monitoring/               # Prometheus & Grafana setup
│   ├── prometheus.yml
│   ├── grafana-dashboards.json
│   ├── postgres_exporter_setup.sh
│   └── queries.yaml
└── LICENSE                   # MIT License
```

## 🧠 Why This Project?

Setting up a PostgreSQL HA cluster can be complex and error-prone. Many solutions rely on Docker or Kubernetes, which may not be suitable for all environments. This project offers:

- **Transparency**: Every configuration file is visible and editable  
- **Simplicity**: Minimal dependencies, native Ubuntu tools  
- **Control**: You decide how each node behaves, with full access to logs and configs  
- **Education**: Great for learning how PostgreSQL HA works under the hood  

## 🖥️ System Requirements

To deploy this cluster, you’ll need:

- 6 Ubuntu Server 22.04 LTS VMs (minimal installation recommended)  
- Static IPs configured via Netplan  
- SSH access and sudo privileges on all nodes  
- No pre-installed PostgreSQL — the setup script handles installation  

## 🧭 Node Roles & IP Plan

| Node Name         | Role                        | Example IP     |
|------------------|-----------------------------|----------------|
| pg-master        | Primary PostgreSQL node     | 10.0.2.101     |
| pg-replica1      | Standby replica             | 10.0.2.102     |
| pg-replica2      | Standby replica             | 10.0.2.103     |
| pgpool-node      | Connection manager (Pgpool) | 10.0.2.104     |
| pgha-node        | HA controller (watchdog)    | 10.0.2.105     |
| monitoring-node  | Prometheus + Grafana        | 10.0.2.106     |

## ⚙️ Installation Guide

### 1. Prepare Working Directory

```bash
sudo mkdir -p /opt/pg-ha && cd /opt/pg-ha
```

### 2. Download Scripts

```bash
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/setup.sh -O setup.sh
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/healthcheck.sh -O healthcheck.sh
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/verify.sh -O verify.sh
chmod +x setup.sh healthcheck.sh verify.sh
```

### 3. Download Configs

```bash
mkdir -p configs monitoring
# PostgreSQL & Pgpool configs
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/postgresql.conf -O configs/postgresql.conf
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pg_hba.conf -O configs/pg_hba.conf
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/network-setup.yaml -O configs/network-setup.yaml
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pgpool.conf -O configs/pgpool.conf
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/watchdog.conf -O configs/watchdog.conf
# Monitoring configs
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/monitoring/prometheus.yml -O monitoring/prometheus.yml
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/monitoring/postgres_exporter_setup.sh -O monitoring/postgres_exporter_setup.sh
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/monitoring/grafana-dashboards.json -O monitoring/grafana-dashboards.json
chmod +x monitoring/postgres_exporter_setup.sh
```

## 🛠️ Setup Script Usage

```bash
./setup.sh <role> [master_ip]
```

- <role>: master, replica, pgpool, pgha, monitoring  
- [master_ip]: Required only for replica nodes  

### Examples

```bash
./setup.sh master
./setup.sh replica 10.0.2.101
./setup.sh pgpool
./setup.sh pgha
./setup.sh monitoring
```

## 📈 Monitoring & Grafana Dashboard

- Access Grafana at: http://<monitoring-node-ip>:3000  
- Import: monitoring/grafana-dashboards.json  
- Metrics include:
  - postgres_up  
  - postgres_replication_lag_seconds  
  - postgres_replication_lag_alert  

### Healthcheck Integration

```bash
(crontab -l 2>/dev/null; echo \"* * * * * /opt/pg-ha/healthcheck.sh\") | crontab -
```

## 🔄 Failover & Recovery Scenarios

### Planned Failover

1. Stop PostgreSQL on master  
2. Promote replica: pg_ctl promote  
3. Update Pgpool config  
4. Restart Pgpool  

### Unplanned Failover

- Pgpool detects failure and promotes replica automatically  
- Verify with: SELECT pg_is_in_recovery();  

### VIP Failover

- Pgpool + PGHA handle virtual IP reassignment  
- Verify with: ip addr show  


## ✅ Post-Installation Checklist

- All nodes reachable via SSH  
- PostgreSQL roles correctly assigned  
- Replication streaming and healthy  
- Pgpool and PGHA running  
- Grafana dashboard active  
- Healthcheck metrics visible  


## 🧰 Troubleshooting Tips

| Issue                     | Solution                                      |
|--------------------------|-----------------------------------------------|
| VIP not moving           | Check watchdog.conf and Pgpool connectivity   |
| Replication lag too high | Investigate disk I/O and network latency      |
| Prometheus not scraping  | Verify targets and firewall rules             |
| Grafana dashboard empty  | Ensure exporters are running                  |


## 📜 License

This project is licensed under the [MIT License](https://github.com/koray-karaman/PostgreSQL-HA-Cluster-VM). You are free to use, modify, and distribute it with proper attribution.


## 🤝 Contributing

Pull requests are welcome! Please ensure your changes are well-documented and tested. If you share this project publicly, kindly link back to the original repository:

👉 [GitHub - koray-karaman/PostgreSQL-HA-Cluster-VM](https://github.com/koray-karaman/PostgreSQL-HA-Cluster-VM)



## 🙌 Author

Built and maintained by [Koray Karaman](https://koraykaraman.com) — for clarity, control, and community.