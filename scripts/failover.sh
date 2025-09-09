#!/bin/bash
# failover.sh — Pgpool-II failover script with repmgr integration

FAILED_NODE_ID=$1
FAILED_NODE_HOST=$2
FAILED_NODE_PORT=$3
FAILED_NODE_DATA=$4
NEW_MASTER_ID=$5
NEW_MASTER_HOST=$6
NEW_MASTER_PORT=$7
NEW_MASTER_DATA=$8

echo "[Failover] Node $FAILED_NODE_ID ($FAILED_NODE_HOST) is down."

# Promote replica using repmgr
echo "[Failover] Promoting replica to master..."
sudo -u postgres repmgr standby promote

# Optional: Restart PostgreSQL to ensure role switch
echo "[Failover] Restarting PostgreSQL service..."
sudo systemctl restart postgresql@14-main

# Optional: Notify or log
echo "[Failover] New master is now active on $(hostname)"