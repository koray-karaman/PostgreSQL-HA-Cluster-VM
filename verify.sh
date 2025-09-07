#!/bin/bash
# PostgreSQL HA Cluster Verification Script
# Checks: PostgreSQL status, role, replication, Pgpool, VIP, Monitoring

PGUSER="postgres"
PGPORT="5432"
PGHOST="localhost"
NODE_EXPORTER_TEXTFILE="/var/lib/node_exporter/textfile_collector"

# Set your VIP here (example: 10.0.2.110)
VIP_IP="${VIP_IP:-10.0.2.110}"

pass() { echo -e "[\e[32mPASS\e[0m] $1"; }
fail() { echo -e "[\e[31mFAIL\e[0m] $1"; }

echo "=== PostgreSQL HA Cluster Verification ==="

# 1. PostgreSQL service
if systemctl is-active --quiet postgresql; then
    pass "PostgreSQL service is running"
else
    fail "PostgreSQL service is NOT running"
fi

# 2. Role check
ROLE=$(psql -U $PGUSER -h $PGHOST -p $PGPORT -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'PRIMARY' END;" 2>/dev/null | xargs)
if [ "$ROLE" == "PRIMARY" ] || [ "$ROLE" == "REPLICA" ]; then
    pass "Node role detected: $ROLE"
else
    fail "Unable to determine node role"
fi

# 3. Replication status (only on primary)
if [ "$ROLE" == "PRIMARY" ]; then
    REPL_COUNT=$(psql -U $PGUSER -h $PGHOST -p $PGPORT -t -c "SELECT count(*) FROM pg_stat_replication;" 2>/dev/null | xargs)
    if [ "$REPL_COUNT" -ge 1 ]; then
        pass "Replication connections: $REPL_COUNT"
    else
        fail "No replication connections detected"
    fi
fi

# 4. Pgpool service (if installed)
if systemctl list-units --type=service | grep -q pgpool2; then
    if systemctl is-active --quiet pgpool2; then
        pass "Pgpool2 service is running"
    else
        fail "Pgpool2 service is NOT running"
    fi
fi

# 5. VIP check (if PGHA node)
if ip addr | grep -q "$VIP_IP"; then
    pass "VIP ($VIP_IP) is assigned to this node"
else
    echo "[INFO] VIP ($VIP_IP) not found on this node (may be standby)"
fi

# 6. Monitoring services (if monitoring node)
if systemctl list-units --type=service | grep -q prometheus; then
    if systemctl is-active --quiet prometheus; then
        pass "Prometheus service is running"
    else
        fail "Prometheus service is NOT running"
    fi
fi
if systemctl list-units --type=service | grep -q grafana-server; then
    if systemctl is-active --quiet grafana-server; then
        pass "Grafana service is running"
    else
        fail "Grafana service is NOT running"
    fi
fi

# 7. Healthcheck metrics file
if [ -d "$NODE_EXPORTER_TEXTFILE" ]; then
    if ls "$NODE_EXPORTER_TEXTFILE"/*.prom >/dev/null 2>&1; then
        pass "Healthcheck metrics file found"
    else
        fail "No .prom metrics file found in $NODE_EXPORTER_TEXTFILE"
    fi
fi

echo "=== Verification complete ==="
