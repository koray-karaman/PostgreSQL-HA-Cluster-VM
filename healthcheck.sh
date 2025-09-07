#!/bin/bash
# PostgreSQL HA Cluster Healthcheck Script with Replication Lag Threshold
# Generates Prometheus-compatible metrics for Node Exporter textfile collector

PGUSER="postgres"
PGPORT="5432"
PGHOST="localhost"
OUTPUT_DIR="/var/lib/node_exporter/textfile_collector"
OUTPUT_FILE="$OUTPUT_DIR/postgres_health.prom"

# Replication lag threshold in seconds (adjust as needed)
LAG_THRESHOLD="${LAG_THRESHOLD:-5}"

mkdir -p "$OUTPUT_DIR"

# 1. PostgreSQL availability
if pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; then
    PG_UP=1
else
    PG_UP=0
fi

# 2. Node role (0 = primary, 1 = replica)
IS_REPLICA=$(psql -U "$PGUSER" -h "$PGHOST" -p "$PGPORT" -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 1 ELSE 0 END;" 2>/dev/null | xargs)

# 3. Replication lag (only on replica)
if [ "$IS_REPLICA" -eq 1 ]; then
    LAG=$(psql -U "$PGUSER" -h "$PGHOST" -p "$PGPORT" -t -c "SELECT COALESCE(EXTRACT(EPOCH FROM now() - pg_last_xact_replay_timestamp()),0);" 2>/dev/null | xargs)
else
    LAG=0
fi

# 4. Lag alert (1 = above threshold, 0 = ok)
if (( $(echo "$LAG > $LAG_THRESHOLD" | bc -l) )); then
    LAG_ALERT=1
else
    LAG_ALERT=0
fi

# Write metrics
cat <<EOF > "$OUTPUT_FILE"
# HELP postgres_up PostgreSQL availability (1=up, 0=down)
# TYPE postgres_up gauge
postgres_up $PG_UP

# HELP postgres_in_recovery Node role (1=replica, 0=primary)
# TYPE postgres_in_recovery gauge
postgres_in_recovery $IS_REPLICA

# HELP postgres_replication_lag_seconds Replication lag in seconds
# TYPE postgres_replication_lag_seconds gauge
postgres_replication_lag_seconds $LAG

# HELP postgres_replication_lag_alert Replication lag alert (1=above threshold, 0=ok)
# TYPE postgres_replication_lag_alert gauge
postgres_replication_lag_alert $LAG_ALERT
EOF