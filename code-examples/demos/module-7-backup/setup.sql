-- Module 7: backup. We'll do this against a single node so the recovery
-- story is unambiguous.
CREATE DATABASE IF NOT EXISTS m7;

DROP TABLE IF EXISTS m7.transactions;
CREATE TABLE m7.transactions
(
    txn_id     UInt64,
    txn_time   DateTime,
    account_id UInt32,
    amount     Decimal(12, 2),
    currency   LowCardinality(String),
    status     LowCardinality(String)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(txn_time)
ORDER BY (account_id, txn_time, txn_id);

INSERT INTO m7.transactions
SELECT
    number AS txn_id,
    toDateTime('2026-01-01 00:00:00') + INTERVAL (number % 7776000) SECOND,
    1 + (rand(number)        % 50000),
    toDecimal64(rand(number+1) % 100000 / 100.0, 2),
    arrayElement(['USD','EUR','INR','JPY'],   1 + toUInt8(rand(number+2) % 4)),
    arrayElement(['ok','pending','reversed'], 1 + toUInt8(rand(number+3) % 3))
FROM numbers(2000000);
