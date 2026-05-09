#!/usr/bin/env bash
# Module 9 — Kafka ingestion.
# Stack: docker-compose-kafka.yml. Container names: clickhouse-kafka, kafka-broker.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROWS=${ROWS:-100000}

echo "==> waiting for clickhouse-kafka"
for _ in $(seq 1 30); do
    docker exec clickhouse-kafka wget --spider -q http://localhost:8123/ping 2>/dev/null && break
    sleep 2
done

ch_kafka() {
    docker exec -i clickhouse-kafka clickhouse-client --multiquery --query "$1"
}

echo "==> create topic 'events' (idempotent)"
docker exec kafka-broker \
    kafka-topics.sh --bootstrap-server localhost:9092 \
        --create --if-not-exists --topic events \
        --partitions 3 --replication-factor 1 >/dev/null

echo "==> setup.sql"
ch_kafka "$(<"$HERE/setup.sql")"

echo "==> producing $ROWS messages → events topic"
python3 "$HERE/produce.py" --rows "$ROWS" \
    | docker exec -i kafka-broker \
        kafka-console-producer.sh --bootstrap-server localhost:9092 --topic events

echo "==> letting the MV catch up (5s)"
sleep 5

echo "==> queries.sql"
ch_kafka "$(<"$HERE/queries.sql")"

cat <<EOF

✓ Module 9 demo complete.

Try:
  • produce more:   ROWS=500000 ./run.sh
  • Kafka UI:       http://localhost:8080
  • watch consumer: docker exec -it clickhouse-kafka clickhouse-client \\
                       -q "SELECT * FROM system.kafka_consumers FORMAT Vertical"
  • DLQ pattern:    add an MV with TO m9.events_dlq filtering on PARSE errors
                    via kafka_handle_error_mode = 'stream' and _error column.
EOF
