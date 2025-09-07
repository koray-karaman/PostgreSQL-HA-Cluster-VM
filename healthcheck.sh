#!/bin/bash
# PostgreSQL Healthcheck Script with Node Exporter textfile output

PGUSER="postgres"
PGHOST="localhost"
PGPORT="5432"
TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"
METRICS_FILE="$TEXTFILE_DIR/postgres_health.prom"

mkdir -p "$TEXTFILE_DIR"

# Check PostgreSQL availability
if pg_isready -h $PGHOST -p $PGPORT -U $PGUSER > /dev/null 2>&1; then
    STATUS=1
else
    STATUS=0
fi

# Determine role (PRIMARY=0, REPLICA=1)
ROLE_QUERY="SELECT CASE WHEN pg_is_in_recovery() THEN 1 ELSE 0 END;"
ROLE=$(psql -U $PGUSER -h $PGHOST -p $PGPORT -t -c "$ROLE_QUERY" 2>/dev/null | xargs)

# Replication lag (seconds)
if [ "$ROLE" -eq 1 ]; then
    LAG_QUERY="SELECT EXTRACT(EPOCH FROM now() - pg_last_xact_replay_timestamp())::INT;"
    LAG=$(psql -U $PGUSER -h $PGHOST -p $PGPORT -t -c "$LAG_QUERY" 2>/dev/null | xargs)
else
    LAG=0
fi

# Write metrics to textfile
cat <<EOF > "$METRICS_FILE"
# HELP postgres_up PostgreSQL availability (1=up, 0=down)
# TYPE postgres_up gauge
postgres_up $STATUS

# HELP postgres_in_recovery Node role (1=replica, 0=primary)
# TYPE postgres_in_recovery gauge
postgres_in_recovery $ROLE

# HELP postgres_replication_lag_seconds Replication lag in seconds
# TYPE postgres_replication_lag_seconds gauge
postgres_replication_lag_seconds $LAG
EOF