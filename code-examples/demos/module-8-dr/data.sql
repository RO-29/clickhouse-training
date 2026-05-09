INSERT INTO dr_distributed
SELECT
    toDateTime('2026-05-01 00:00:00') + INTERVAL (number % 86400) SECOND,
    1 + rand(number) % 1000000,
    repeat('x', 50 + rand(number+1) % 100)
FROM numbers(1000000);
