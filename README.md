# PostgreSQL HA Cluster on Virtual Machines

A fully automated setup for a PostgreSQL High Availability cluster using Ubuntu Server VMs.  
This project creates a resilient PostgreSQL cluster with primary and replica nodes, managed by Pgpool and HAProxy, and monitored via Prometheus + Grafana.

---

## Default Ubuntu Setup for This Project

To ensure consistent installation and operation of the PostgreSQL HA Cluster, all nodes should start from the same base environment. The following specifications define the default Ubuntu setup for this project:

- **Operating System:** Ubuntu Server 22.04 LTS (minimal installation is recommended to avoid unnecessary packages and services).
- **Package Manager:** `apt` (default on Ubuntu).
- **User Account:** A user account with `sudo` privileges (either the root account or a non-root user in the sudoers group).
- **Network Configuration:** Each node must have a static IP address configured using `netplan`. The static IP should match the IP plan defined in the project documentation.
- **SSH Access:** SSH must be enabled and accessible for remote administration.
- **PostgreSQL Installation:** PostgreSQL is **not pre-installed**. The `setup.sh` script will install PostgreSQL and any required extensions according to the node’s role:
  - On **master** and **replica** nodes, `setup.sh` will run `apt install postgresql postgresql-contrib` to install PostgreSQL.
  - The default PostgreSQL version is **15**, which is the version available in the official Ubuntu 22.04 package repositories.
- **Additional Services:** Pgpool-II, PGHA (Pgpool watchdog + VIP management), Prometheus, and Grafana are **not pre-installed**. These services will be installed automatically by `setup.sh` when running on their respective node roles.
- **System Updates:** It is recommended to update the system before running any setup scripts:
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```
- **Clean Environment:** The installation assumes a clean system without conflicting PostgreSQL or Pgpool installations. Pre-existing installations may interfere with configuration and replication setup.

> **Note:** Starting from a minimal, clean Ubuntu Server 22.04 LTS environment ensures that the `setup.sh` script can configure each node consistently and without conflicts.

---

## Quick Install from GitHub

You can install each node role by downloading the scripts and configs directly from this repository’s raw URLs.

**Base URL:**
```
https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main
```

### 1️⃣ Prepare working directory
```bash
sudo mkdir -p /opt/pg-ha && cd /opt/pg-ha
```

### 2️⃣ Download core scripts
```bash
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/setup.sh -O setup.sh
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/healthcheck.sh -O healthcheck.sh
chmod +x setup.sh healthcheck.sh
```

### 3️⃣ Download configs
```bash
mkdir -p configs monitoring

# Configs
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/postgresql.conf -O configs/postgresql.conf
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pg_hba.conf -O configs/pg_hba.conf
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/network-setup.yaml -O configs/network-setup.yaml
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pgpool.conf -O configs/pgpool.conf
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pgpool-healthcheck.conf -O configs/pgpool-healthcheck.conf
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/watchdog.conf -O configs/watchdog.conf

# Monitoring
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/monitoring/prometheus.yml -O monitoring/prometheus.yml
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/monitoring/postgres_exporter_setup.sh -O monitoring/postgres_exporter_setup.sh
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/monitoring/queries.yaml -O monitoring/queries.yaml
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/monitoring/grafana-dashboards.json -O monitoring/grafana-dashboards.json
chmod +x monitoring/postgres_exporter_setup.sh
```

### 4️⃣ Run setup by role

Replace `<MASTER_IP>` with your primary node’s IP.

- **Master node:**
```bash
./setup.sh master
```

- **Replica node:**
```bash
./setup.sh replica <MASTER_IP>
```

- **Pgpool node:**
```bash
./setup.sh pgpool
```

- **PGHA node:**
```bash
./setup.sh pgha
```

- **Monitoring node:**
```bash
./setup.sh monitoring
```

### 5️⃣ Enable healthcheck on DB nodes
```bash
(crontab -l 2>/dev/null; echo "* * * * * /opt/pg-ha/healthcheck.sh") | crontab -
```

---

## Project Structure

```text
postgres-ha-cluster-vm/
├── setup.sh
├── healthcheck.sh
├── verify.sh
├── configs/
│   ├── postgresql.conf
│   ├── pg_hba.conf
│   ├── network-setup.yaml
│   ├── pgpool.conf
│   ├── pgpool-healthcheck.conf
│   └── watchdog.conf
├── monitoring/
│   ├── prometheus.yml
│   ├── postgres_exporter_setup.sh
│   ├── grafana-dashboards.json
│   ├── queries.yaml
│   └── README.md
├── README.md
├── LICENSE
└── .gitignore
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

---

## Monitoring & Dashboard

This project includes Prometheus + Grafana integration for real-time cluster monitoring, with `healthcheck.sh` integrated into Node Exporter’s textfile collector for unified metrics.

Example metrics from `healthcheck.sh`:
```
# HELP postgres_up PostgreSQL availability (1=up, 0=down)
# TYPE postgres_up gauge
postgres_up 1

# HELP postgres_in_recovery Node role (1=replica, 0=primary)
# TYPE postgres_in_recovery gauge
postgres_in_recovery 0

# HELP postgres_replication_lag_seconds Replication lag in seconds
# TYPE postgres_replication_lag_seconds gauge
postgres_replication_lag_seconds 0
```

---

## Installation Guide
## Installation Guide

### Prerequisites
- 6 Virtual Machines (Ubuntu Server 22.04 LTS recommended)
- Static IP for each VM (configured via `netplan`)
- SSH access to each node
- Sudo privileges on each node
- Clean environment (no pre-installed PostgreSQL, Pgpool, Prometheus, or Grafana)

---

### Node Roles & IP Plan
| Node Name         | Role                          | Example IP     |
|-------------------|-------------------------------|----------------|
| pg-master         | Primary PostgreSQL node       | 10.0.2.101     |
| pg-replica1       | Standby node                  | 10.0.2.102     |
| pg-replica2       | Standby node                  | 10.0.2.103     |
| pgpool-node       | Connection manager            | 10.0.2.104     |
| pgha-node         | HA controller (watchdog)      | 10.0.2.105     |
| monitoring-node   | Prometheus + Grafana dashboard| 10.0.2.106     |

---

### Installation Order

#### 1️⃣ Configure Network (All Nodes)
```bash
sudo cp configs/network-setup.yaml /etc/netplan/00-installer-config.yaml
sudo netplan apply
```
> ⚠️ **Warning:** Do not run `ip addr flush` on a VM accessed via SSH — it will drop your connection.

---

#### 2️⃣ Master Node Setup
On `pg-master`:
```bash
./setup.sh master
```
- Installs PostgreSQL
- Creates `replica` user for streaming replication
- Applies `postgresql.conf` and `pg_hba.conf`
- Starts PostgreSQL service

---

#### 3️⃣ Replica Nodes Setup
On each replica node:
```bash
./setup.sh replica 10.0.2.101
```
- Stops PostgreSQL
- Clears existing data directory
- Runs `pg_basebackup` from master
- Configures replication settings
- Starts PostgreSQL in standby mode

---

#### 4️⃣ Pgpool Node Setup
On `pgpool-node`:
```bash
./setup.sh pgpool
```
- Installs Pgpool-II
- Applies `pgpool.conf` and `pgpool-healthcheck.conf`
- Enables and starts Pgpool service

---

#### 5️⃣ PGHA Node Setup
On `pgha-node`:
```bash
./setup.sh pgha
```
- Installs Pgpool-II with Watchdog
- Applies `watchdog.conf`
- Configures Virtual IP (VIP) for failover
- Enables and starts Pgpool service

---

#### 6️⃣ Monitoring Node Setup
On `monitoring-node`:
```bash
./setup.sh monitoring
```
- Installs Prometheus and Grafana
- Applies `prometheus.yml`
- Installs PostgreSQL Exporter
- Enables and starts monitoring services

---

#### 7️⃣ Enable Healthcheck on DB Nodes
On each **master** and **replica** node:
```bash
(crontab -l 2>/dev/null; echo "* * * * * /opt/pg-ha/healthcheck.sh") | crontab -
```
- Runs `healthcheck.sh` every minute
- Outputs metrics to Node Exporter textfile collector

---

#### 8️⃣ Import Grafana Dashboard
- Open Grafana at `http://<monitoring-node-ip>:3000`
- Login (default: `admin` / `admin`)
- Import `monitoring/grafana-dashboards.json`
- Select Prometheus as the data source

---

### Verification
- Use `verify.sh` to confirm all services and roles are correct:
```bash
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/verify.sh -O verify.sh
chmod +x verify.sh
./verify.sh
```


---

## Failover & Recovery Scenarios

This section describes how to test and recover from failover events in the PostgreSQL HA Cluster.

---

### 1️⃣ Planned Failover (Maintenance)

**Goal:** Promote a replica to primary without data loss.

**Steps:**
1. Choose the replica to promote (e.g., `pg-replica1`).
2. On the current primary (`pg-master`), stop PostgreSQL:
   ```bash
   sudo systemctl stop postgresql
   ```
3. On the chosen replica:
   ```bash
   sudo -u postgres pg_ctl promote
   ```
4. Update `pgpool.conf` to point to the new primary.
5. Restart Pgpool:
   ```bash
   sudo systemctl restart pgpool2
   ```
6. Rebuild the old primary as a replica before bringing it back online.

---

### 2️⃣ Unplanned Failover (Primary Crash)

**Goal:** Ensure Pgpool automatically promotes a healthy replica.

**Steps:**
1. Simulate a crash on the primary:
   ```bash
   sudo systemctl stop postgresql
   ```
2. Pgpool should detect the failure via health checks and promote a replica.
3. Verify the new primary:
   ```bash
   psql -U postgres -c "SELECT pg_is_in_recovery();"
   ```
   - `f` = Primary
   - `t` = Replica
4. Check Grafana for failover event visualization.

---

### 3️⃣ Recovery of Failed Primary

**Goal:** Reintegrate the failed primary as a replica.

**Steps:**
1. On the failed node, ensure PostgreSQL is stopped:
   ```bash
   sudo systemctl stop postgresql
   ```
2. Clear the old data directory:
   ```bash
   sudo rm -rf /var/lib/postgresql/15/main/*
   ```
3. Run base backup from the current primary:
   ```bash
   sudo -u postgres pg_basebackup -h <NEW_PRIMARY_IP> -D /var/lib/postgresql/15/main -U replica -P -R
   ```
4. Start PostgreSQL:
   ```bash
   sudo systemctl start postgresql
   ```
5. Verify replication status:
   ```bash
   psql -U postgres -c "SELECT pg_is_in_recovery();"
   ```

---

### 4️⃣ VIP Failover (Pgpool + PGHA)

**Goal:** Ensure the Virtual IP moves to the standby Pgpool node.

**Steps:**
1. Stop Pgpool on the active node:
   ```bash
   sudo systemctl stop pgpool2
   ```
2. PGHA should detect the failure and assign the VIP to the standby Pgpool node.
3. Verify VIP assignment:
   ```bash
   ip addr show
   ```
4. Test client connections to the VIP.

---

### 5️⃣ Monitoring Failover Events

**Goal:** Track failover events in Grafana.

**Steps:**
1. Ensure `healthcheck.sh` is running on all DB nodes via cron.
2. In Grafana, use the PostgreSQL HA dashboard to:
   - View `postgres_in_recovery` changes over time.
   - Monitor replication lag before and after failover.
   - Correlate failover events with system metrics (CPU, memory, network).

---

### Best Practices

- Always test failover in a staging environment before production.
- Keep `pg_hba.conf` and `postgresql.conf` consistent across all nodes.
- Regularly monitor replication lag to prevent data loss during failover.
- Document IP addresses, roles, and credentials for quick recovery.

---

## Post-Installation Verification Checklist

Use this checklist to verify that your PostgreSQL HA Cluster is fully operational after installation.

---

### 1️⃣ Network & Connectivity
- [ ] All nodes have the correct static IP addresses.
- [ ] Each node can ping every other node.
- [ ] SSH access works for all nodes.

---

### 2️⃣ PostgreSQL Status
- [ ] On `pg-master`, run:
  ```bash
  psql -U postgres -c "SELECT pg_is_in_recovery();"
  ```
  Output should be `f` (false) → Primary.
- [ ] On each replica, run the same command:
  Output should be `t` (true) → Replica.
- [ ] `pg_isready` returns `accepting connections` on all nodes.

---

### 3️⃣ Replication Health
- [ ] On `pg-master`, run:
  ```bash
  psql -U postgres -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"
  ```
  All replicas should appear with `state = streaming`.
- [ ] Replication lag is within acceptable limits (check Grafana or run lag query).

---

### 4️⃣ Pgpool & PGHA
- [ ] Pgpool is running on `pgpool-node` and `pgha-node`:
  ```bash
  systemctl status pgpool2
  ```
- [ ] VIP is assigned to the active Pgpool node:
  ```bash
  ip addr show
  ```
- [ ] Stopping Pgpool on the active node moves the VIP to the standby node.

---

### 5️⃣ Monitoring & Dashboard
- [ ] Prometheus is running on `monitoring-node`:
  ```bash
  systemctl status prometheus
  ```
- [ ] Grafana is running and accessible at `http://monitoring-node:3000`.
- [ ] `healthcheck.sh` is running via cron on all DB nodes.
- [ ] Grafana dashboard shows:
  - PostgreSQL Availability
  - Node Role (Primary / Replica)
  - Replication Lag
  - Active Connections
  - CPU / Memory Usage

---

### 6️⃣ Failover Test
- [ ] Stop PostgreSQL on `pg-master`:
  ```bash
  sudo systemctl stop postgresql
  ```
- [ ] Pgpool promotes a replica to primary automatically.
- [ ] Grafana reflects the role change.
- [ ] Restart the old primary as a replica and verify replication.

---

### 7️⃣ Maintenance Checks
- [ ] All config files (`postgresql.conf`, `pg_hba.conf`, `pgpool.conf`, `watchdog.conf`) are consistent across nodes.
- [ ] Logs are free of critical errors:
  ```bash
  journalctl -u postgresql
  journalctl -u pgpool2
  ```
- [ ] Backups are configured and tested.

---

✅ If all boxes are checked, your PostgreSQL HA Cluster is ready for production.


---

## Post-Installation Verification

After completing the installation, you can verify your node’s health using the `verify.sh` script.

### 1️⃣ Download & Run
```bash
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/verify.sh -O verify.sh
chmod +x verify.sh
./verify.sh
```

### 2️⃣ Setting the VIP IP
By default, `verify.sh` checks for the VIP `10.0.2.110`.  
If your environment uses a different VIP, set it before running the script:
```bash
export VIP_IP="192.168.1.200"
./verify.sh
```
Or edit the `VIP_IP` variable inside `verify.sh`.

---

### 3️⃣ What it checks
- PostgreSQL service status
- Node role (Primary / Replica)
- Replication connections (on Primary)
- Pgpool2 service status
- VIP presence (for PGHA node, using the configured `VIP_IP`)
- Prometheus & Grafana services (for monitoring node)
- Healthcheck `.prom` file presence

---

### 4️⃣ Example output
```
=== PostgreSQL HA Cluster Verification ===
[PASS] PostgreSQL service is running
[PASS] Node role detected: PRIMARY
[PASS] Replication connections: 2
[PASS] Pgpool2 service is running
[INFO] VIP (192.168.1.200) not found on this node (may be standby)
[PASS] Prometheus service is running
[PASS] Grafana service is running
[PASS] Healthcheck metrics file found
=== Verification complete ===
```

✅ If all critical checks pass, your node is healthy and ready for production.

## License & Sharing

### License
This project is licensed under the **MIT License**.

```
MIT License

Copyright (c) 2025 Koray Karaman

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

### Sharing & Contribution
- You are free to **fork** this repository and adapt it to your needs.
- Contributions via **pull requests** are welcome — please ensure your changes are well-documented and tested.
- If you share this project publicly, please include a link back to the original repository:
  ```
  https://github.com/koray-karaman/PostgreSQL-HA-Cluster-VM
  ```
- For bug reports or feature requests, open an **issue** in the repository.

---

**Built by [Koray Karaman](https://github.com/koray-karaman) — for clarity, control, and community.**