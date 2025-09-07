# PostgreSQL HA Cluster on Virtual Machines

A fully automated setup for a PostgreSQL High Availability cluster using Ubuntu Server VMs.  
This project creates a resilient PostgreSQL cluster with primary and replica nodes, managed by Pgpool and HAProxy, and monitored via Prometheus + Grafana.

---

## Default Ubuntu Setup for This Project

To ensure consistent installation and operation of the PostgreSQL HA Cluster, all nodes should start from the same base environment:

- **Operating System:** Ubuntu Server 22.04 LTS (minimal installation recommended)
- **Package Manager:** `apt`
- **User Account:** A user account with `sudo` privileges
- **Network Configuration:** Static IP via `netplan`
- **SSH Access:** Enabled and accessible
- **PostgreSQL:** Not pre-installed — installed by `setup.sh` according to node role
- **Additional Services:** Pgpool-II, PGHA, Prometheus, Grafana — installed by `setup.sh` for their roles
- **System Updates:**  
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```
- **Clean Environment:** No conflicting PostgreSQL/Pgpool installations

---

## Quick Install from GitHub

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
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/verify.sh -O verify.sh
chmod +x setup.sh healthcheck.sh verify.sh
```

### 3️⃣ Download configs
```bash
mkdir -p configs monitoring
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/postgresql.conf -O configs/postgresql.conf
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pg_hba.conf -O configs/pg_hba.conf
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/network-setup.yaml -O configs/network-setup.yaml
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pgpool.conf -O configs/pgpool.conf
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/pgpool-healthcheck.conf -O configs/pgpool-healthcheck.conf
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/configs/watchdog.conf -O configs/watchdog.conf
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/monitoring/prometheus.yml -O monitoring/prometheus.yml
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/monitoring/postgres_exporter_setup.sh -O monitoring/postgres_exporter_setup.sh
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/monitoring/queries.yaml -O monitoring/queries.yaml
wget -q https://raw.githubusercontent.com/koray-karaman/PostgreSQL-HA-Cluster-VM/main/monitoring/grafana-dashboards.json -O monitoring/grafana-dashboards.json
chmod +x monitoring/postgres_exporter_setup.sh
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

---

## Installation Guide

### Prerequisites
- 6 VMs (Ubuntu Server 22.04 LTS)
- Static IPs
- SSH access
- Sudo privileges

### Node Roles & IP Plan
| Node Name       | Role                          | Example IP     |
|-----------------|-------------------------------|----------------|
| pg-master       | Primary PostgreSQL node       | 10.0.2.101     |
| pg-replica1     | Standby node                  | 10.0.2.102     |
| pg-replica2     | Standby node                  | 10.0.2.103     |
| pgpool-node     | Connection manager            | 10.0.2.104     |
| pgha-node       | HA controller (watchdog)      | 10.0.2.105     |
| monitoring-node | Prometheus + Grafana dashboard| 10.0.2.106     |

---

### Installation Order

1️⃣ **Network Configuration** (all nodes)  
```bash
sudo cp configs/network-setup.yaml /etc/netplan/00-installer-config.yaml
sudo netplan apply
```

2️⃣ **Master Node**  
```bash
export MASTER_IP="10.0.2.101"
./setup.sh master
```

3️⃣ **Replica Nodes**  
```bash
./setup.sh replica $MASTER_IP
```

4️⃣ **Pgpool Node**  
```bash
./setup.sh pgpool
```

5️⃣ **PGHA Node**  
```bash
./setup.sh pgha
```

6️⃣ **Monitoring Node**  
```bash
./setup.sh monitoring
```

7️⃣ **Healthcheck on DB Nodes**  
```bash
(crontab -l 2>/dev/null; echo "* * * * * /opt/pg-ha/healthcheck.sh") | crontab -
```

8️⃣ **Grafana Dashboard**  
- Access Grafana at `http://<monitoring-node-ip>:3000`
- Import `monitoring/grafana-dashboards.json`

---

## Monitoring & Dashboard

This project includes Prometheus + Grafana integration for real-time cluster monitoring, with `healthcheck.sh` integrated into Node Exporter’s textfile collector for unified metrics.

The improved `healthcheck.sh` includes a **replication lag threshold** feature, generating an additional alert metric when lag exceeds a configurable limit.

Example metrics:
```
postgres_up 1
postgres_in_recovery 0
postgres_replication_lag_seconds 0
postgres_replication_lag_alert 0
```

- Default threshold: **5 seconds**  
- Change threshold:
  ```bash
  export LAG_THRESHOLD=10
  ./healthcheck.sh
  ```
- Grafana alert rule: `postgres_replication_lag_alert == 1`

**Setup Steps:**
1. Install PostgreSQL Exporter on DB nodes.
2. Install Node Exporter with textfile collector.
3. Schedule `healthcheck.sh` via cron.
4. Start Prometheus with `monitoring/prometheus.yml`.
5. Start Grafana and import `monitoring/grafana-dashboards.json`.

**Dashboard Features:**
- PostgreSQL Availability
- Node Role
- Replication Lag
- **Replication Lag Alert**
- Active Connections
- CPU / Memory Usage
- Failover Events

---

## Failover & Recovery Scenarios

This section describes how to test and recover from failover events in the PostgreSQL HA Cluster.

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

```bash
export VIP_IP="10.0.2.110"   # Change if needed
./verify.sh
```
Checks:
- PostgreSQL service
- Node role
- Replication
- Pgpool
- VIP presence
- Monitoring services
- Healthcheck metrics

---

## Troubleshooting

**Common Issues & Fixes:**
- **VIP not moving:** Check `watchdog.conf` and ensure both Pgpool nodes can ping each other.
- **Replication lag high:** Check network latency and disk I/O on replicas.
- **Prometheus not scraping:** Verify `prometheus.yml` targets and firewall rules.
- **Grafana dashboard empty:** Ensure exporters are running and Prometheus has recent data.
- **verify.sh VIP mismatch:** Set `VIP_IP` before running:
  ```bash
  export VIP_IP="192.168.1.200"
  ./verify.sh
  ```

---

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