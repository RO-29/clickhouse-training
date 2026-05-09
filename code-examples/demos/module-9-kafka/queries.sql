-- Wait a couple of seconds for the MV to consume newly-produced messages,
-- then run these.

-- Total durably-inserted rows
SELECT count() AS rows, max(event_time) AS latest_event FROM m9.events;

-- Per-event-type breakdown (from the destination MergeTree)
SELECT event_type, count() AS rows, round(sum(revenue), 2) AS revenue
FROM m9.events GROUP BY event_type ORDER BY rows DESC;

-- The pre-aggregated SummingMergeTree (60s buckets)
SELECT minute, event_type, sum(events) AS events, round(sum(revenue), 2) AS revenue
FROM m9.events_per_minute
GROUP BY minute, event_type ORDER BY minute, event_type LIMIT 20;

-- How is consumer lag looking?
SELECT
    database,
    table,
    consumer_id,
    assignments.topic        AS topic,
    assignments.partition_id AS partition,
    assignments.current_offset AS offset
FROM system.kafka_consumers
ARRAY JOIN assignments
WHERE database = 'm9';

-- Have any messages failed parsing? Check the system.kafka error metrics.
SELECT *
FROM system.events
WHERE event LIKE 'Kafka%'
ORDER BY event;
