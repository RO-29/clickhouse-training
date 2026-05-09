-- Module 5 extras: SQL-managed users/roles/grants on top of users.xml.
--
-- users.xml ships three users (admin, analyst, app), all with password
-- 'admin' (sha256). Below we layer SQL roles/grants for fine-grained
-- access on the analytics database created in setup.sql.

-- ============================================================
-- 1. Roles and grants
-- ============================================================
CREATE ROLE IF NOT EXISTS reader      ON CLUSTER clickhouse_cluster;
CREATE ROLE IF NOT EXISTS writer      ON CLUSTER clickhouse_cluster;

GRANT SELECT ON analytics.*                        TO reader  ON CLUSTER clickhouse_cluster;
GRANT INSERT ON analytics.page_views_distributed    TO writer  ON CLUSTER clickhouse_cluster;
GRANT INSERT ON analytics.page_views_local          TO writer  ON CLUSTER clickhouse_cluster;

-- Bind roles to the users from users.xml.
GRANT reader TO analyst ON CLUSTER clickhouse_cluster;
GRANT writer TO app     ON CLUSTER clickhouse_cluster;

-- ============================================================
-- 2. Inspect the result
-- ============================================================
SELECT name, storage, host_ip FROM system.users  WHERE name IN ('admin','analyst','app') ORDER BY name;
SELECT name, storage              FROM system.roles  ORDER BY name;
SELECT user_name, role_name, granted_role_is_default
FROM system.role_grants WHERE user_name IN ('analyst','app') ORDER BY user_name;
SELECT user_name, role_name, access_type, database, table
FROM system.grants WHERE user_name IS NULL AND role_name IN ('reader','writer')
ORDER BY role_name, access_type;

-- ============================================================
-- 3. Quotas — counters from system tables.
-- ============================================================
SELECT name, keys, queries, errors, read_rows
FROM system.quotas_usage WHERE name IN ('default','analyst_quota');

-- ============================================================
-- 4. Prometheus endpoint — built into the server.
--    Scrape with: wget -qO- http://m5-s1r1:9363/metrics  (from inside the
--    docker network), or expose host ports per-node in the compose if you
--    want to scrape from the host.
-- ============================================================
SELECT 'Prometheus endpoint enabled on every node, port 9363, path /metrics';

-- ============================================================
-- 5. TLS (port 9440) — not configured in this demo to keep certs out
--    of source control. Production sketch:
--      <https_port>8443</https_port>
--      <tcp_port_secure>9440</tcp_port_secure>
--      <openSSL>...<certificateFile/><privateKeyFile/>...</openSSL>
--    Generate certs with mkcert or step-ca, then mount under
--    /etc/clickhouse-server/ and reload.
-- ============================================================
