-- 20 million rows into all three tables, identical data so timings are comparable.
-- Single INSERT per table to avoid burning disk on dupes.

INSERT INTO m6.events_good
SELECT
    toDateTime('2026-01-01 00:00:00') + INTERVAL (number % 7776000) SECOND,
    1 + (rand(number)        % 500000),
    arrayElement(['US','IN','DE','BR','JP','GB','FR','CA','AU','MX'],
                 1 + toUInt8(rand(number+1) % 10)),
    arrayElement(['ios','android','web','tv'],
                 1 + toUInt8(rand(number+2) % 4)),
    arrayElement(['view','click','purchase','signup','logout','search'],
                 1 + toUInt8(rand(number+3) % 6)),
    rand(number+4) / 4294967295.0 * 500,
    concat('/p/', toString(rand(number+5) % 9999))
FROM numbers(20000000);

-- copy into the other two layouts
INSERT INTO m6.events_bad  SELECT * FROM m6.events_good;
INSERT INTO m6.events_proj SELECT * FROM m6.events_good;

-- compact
OPTIMIZE TABLE m6.events_good FINAL;
OPTIMIZE TABLE m6.events_bad  FINAL;
OPTIMIZE TABLE m6.events_proj FINAL;
