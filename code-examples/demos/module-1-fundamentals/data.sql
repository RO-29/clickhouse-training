-- 2 million synthetic rows, generated entirely in ClickHouse via numbers().
-- Multiple INSERT statements so we end up with several parts that merge over time.

INSERT INTO m1.events
SELECT
    toDateTime('2026-01-01 00:00:00') + INTERVAL (number % 7776000) SECOND AS event_time,
    toUInt32(1 + (rand(number)         % 100000))                          AS user_id,
    arrayElement(['US','IN','DE','BR','JP','GB','FR','CA','AU','MX'],
                 1 + toUInt8(rand(number + 1)  % 10))                       AS country,
    arrayElement(['ios','android','web','tv'],
                 1 + toUInt8(rand(number + 2)  % 4))                        AS device,
    arrayElement(['view','click','purchase','signup','logout','search'],
                 1 + toUInt8(rand(number + 3)  % 6))                        AS event_type,
    if(event_type = 'purchase',
       round(5 + rand(number + 4) % 24500 / 100, 2),
       0.0)                                                                 AS revenue,
    generateUUIDv4()                                                        AS session_id,
    concat('/p/', toString(rand(number + 5) % 9999))                        AS url
FROM numbers(500000);

INSERT INTO m1.events
SELECT
    toDateTime('2026-02-01 00:00:00') + INTERVAL (number % 2592000) SECOND,
    toUInt32(1 + rand(number) % 100000),
    arrayElement(['US','IN','DE','BR','JP','GB','FR','CA','AU','MX'], 1 + toUInt8(rand(number+1)%10)),
    arrayElement(['ios','android','web','tv'], 1 + toUInt8(rand(number+2)%4)),
    arrayElement(['view','click','purchase','signup','logout','search'], 1 + toUInt8(rand(number+3)%6)),
    if(rand(number+3)%6 = 2, round(5 + rand(number+4)%24500/100, 2), 0.0),
    generateUUIDv4(),
    concat('/p/', toString(rand(number+5)%9999))
FROM numbers(500000);

INSERT INTO m1.events
SELECT
    toDateTime('2026-03-01 00:00:00') + INTERVAL (number % 2592000) SECOND,
    toUInt32(1 + rand(number) % 100000),
    arrayElement(['US','IN','DE','BR','JP','GB','FR','CA','AU','MX'], 1 + toUInt8(rand(number+1)%10)),
    arrayElement(['ios','android','web','tv'], 1 + toUInt8(rand(number+2)%4)),
    arrayElement(['view','click','purchase','signup','logout','search'], 1 + toUInt8(rand(number+3)%6)),
    if(rand(number+3)%6 = 2, round(5 + rand(number+4)%24500/100, 2), 0.0),
    generateUUIDv4(),
    concat('/p/', toString(rand(number+5)%9999))
FROM numbers(1000000);
