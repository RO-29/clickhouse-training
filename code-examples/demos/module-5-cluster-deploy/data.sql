INSERT INTO analytics.page_views_distributed
SELECT
    toDateTime('2026-04-01 00:00:00') + INTERVAL (number % 2592000) SECOND,
    1 + rand(number) % 200000,
    arrayElement(['home','search','product','checkout','blog'], 1 + toUInt8(rand(number+1) % 5)),
    arrayElement(['google','direct','email','social'],          1 + toUInt8(rand(number+2) % 4)),
    100 + rand(number+3) % 30000
FROM numbers(3000000);
