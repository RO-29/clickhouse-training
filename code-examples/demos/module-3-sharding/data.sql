-- Insert through the Distributed table; rows fan out to the right shard.
-- 5 million rows, 250k distinct users → enough to see balance across 3 shards.

INSERT INTO hits_distributed
SELECT
    toDateTime('2026-01-01 00:00:00') + INTERVAL (number % 7776000) SECOND,
    1 + (rand(number)        % 250000),
    arrayElement(['US','IN','DE','BR','JP','GB','FR','CA','AU','MX'],
                 1 + toUInt8(rand(number+1)%10)),
    concat('/u/', toString(rand(number+2) % 9999)),
    100 + rand(number+3) % 100000
FROM numbers(5000000);
