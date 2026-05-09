-- Insert into one replica of shard 1 only (sensor_local on s1r1). The other
-- replica (s1r2) should pick it up via the replication queue.

INSERT INTO sensor_local
SELECT
    toDateTime('2026-05-01 00:00:00') + INTERVAL (number % 86400) SECOND,
    1 + (rand(number)   % 5000),
    arrayElement(['us','eu','ap'], 1 + toUInt8(rand(number+1) % 3)),
    rand(number+2) / 4294967295.0 * 100
FROM numbers(2000000);
