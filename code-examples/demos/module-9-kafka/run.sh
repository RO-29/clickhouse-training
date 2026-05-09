#!/usr/bin/env bash
# Module 9 — Kafka ingestion. Standalone stack.
# Container names: m9-clickhouse, m9-kafka, m9-zk, m9-kafka-ui.
# Note: Confluent images use 'kafka-topics' (no .sh).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROWS=${ROWS:-100000}

if ! docker exec m9-clickhouse wget --spider -q http://localhost:8123/ping 2>/dev/null; then
    "$HERE/up.sh"
fi

ch() { docker exec -i m9-clickhouse clickhouse-client --multiquery --query "$1"; }

echo "==> create topic 'events' (idempotent)"
docker exec m9-kafka \
    kafka-topics --bootstrap-server localhost:9092 \
        --create --if-not-exists --topic events \
        --partitions 3 --replication-factor 1 >/dev/null

echo "==> setup.sql"
ch "$(<"$HERE/setup.sql")"

echo "==> extras.sql (DLQ pipeline + exactly-once Replacing + safe consumer)"
ch "$(<"$HERE/extras.sql")"

echo "==> producing $ROWS valid messages → events topic"
python3 "$HERE/produce.py" --rows "$ROWS" \
    | docker exec -i m9-kafka \
        kafka-console-producer --bootstrap-server localhost:9092 --topic events

echo "==> producing 50 deliberately-broken messages (DLQ exercise)"
for i in $(seq 1 50); do
    echo "{not valid json #$i"
done | docker exec -i m9-kafka \
        kafka-console-producer --bootstrap-server localhost:9092 --topic events

echo "==> letting MVs catch up (8s)"
sleep 8

echo "==> queries.sql"
ch "$(<"$HERE/queries.sql")"

echo "==> DLQ + exactly-once verification"
ch "SELECT 'events_dlq rows', count() FROM m9.events_dlq;
    SELECT 'events_safe rows', count() FROM m9.events_safe;
    SELECT 'events_unique rows (FINAL)', count() FROM m9.events_unique FINAL;
    SELECT error, count() FROM m9.events_dlq GROUP BY error ORDER BY count() DESC LIMIT 3;"

cat <<EOF

✓ Module 9 demo complete.

  • produce more:   ROWS=500000 ./run.sh
  • Kafka UI:       http://localhost:8080
  • watch consumer: docker exec -it m9-clickhouse clickhouse-client \\
                       -q "SELECT * FROM system.kafka_consumers FORMAT Vertical"

Stack still running. Tear down with:  ./down.sh
EOF
