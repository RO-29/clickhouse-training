-- ReplacingMergeTree: insert duplicates, then v2 of the same user.
INSERT INTO m2.users_replacing (user_id, name, email, version) VALUES
    (1, 'alice',  'alice@old.com',  1),
    (2, 'bob',    'bob@old.com',    1),
    (3, 'carol',  'carol@old.com',  1);

INSERT INTO m2.users_replacing (user_id, name, email, version) VALUES
    (1, 'alice',  'alice@new.com',  2),     -- newer version of alice
    (2, 'bob',    'bob@new.com',    2),     -- newer version of bob
    (3, 'carol',  'carol@gone.com', 3),     -- newer still
    (3, 'carol',  'carol@gone.com', 4);     -- and again

-- SummingMergeTree: lots of partial counters that should add up after a merge.
INSERT INTO m2.metrics_summing (metric_date, metric, region, value, count)
SELECT
    toDate('2026-05-01') + (number % 7),
    arrayElement(['cpu','mem','disk','net'], 1 + number % 4),
    arrayElement(['us','eu','ap'],            1 + number % 3),
    1 + number % 50,
    1
FROM numbers(50000);

-- AggregatingMergeTree: load aggregate STATES, not raw values.
INSERT INTO m2.events_agg
SELECT
    toDate('2026-05-01') + (number % 30) AS bucket_date,
    arrayElement(['US','IN','DE','BR'], 1 + number % 4) AS country,
    uniqState(toUInt32(1 + number % 50000))             AS uniq_users_state,
    sumState(toFloat64(rand(number) % 1000) / 7)        AS revenue_state,
    quantileTDigestState(0.99)(toFloat64(rand(number) % 5000) / 13) AS p99_state
FROM numbers(200000)
GROUP BY bucket_date, country;

-- CollapsingMergeTree: insert orders, then cancel/replace one of them.
INSERT INTO m2.orders_collapsing VALUES
    (101, 'pending',  10.0,  1),
    (102, 'pending',  20.0,  1),
    (103, 'pending',  30.0,  1);

-- Now order 101 is paid: cancel old row, write new row.
INSERT INTO m2.orders_collapsing VALUES
    (101, 'pending', 10.0, -1),
    (101, 'paid',    10.0,  1);

-- Log + Memory + Buffer
INSERT INTO m2.audit_log VALUES
    (now(), 'alice', 'login'),
    (now(), 'bob',   'export-data'),
    (now(), 'alice', 'logout');

INSERT INTO m2.tmp_uploads SELECT generateUUIDv4(), repeat('x', 100) FROM numbers(1000);

INSERT INTO m2.facts_buffer
SELECT now() - (number % 600),
       arrayElement(['cpu','mem','rps'], 1 + number % 3),
       rand(number) / 4294967295.0 * 100
FROM numbers(5000);
