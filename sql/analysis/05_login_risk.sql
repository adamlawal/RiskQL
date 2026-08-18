-- =============================================================================
-- 05_login_risk.sql
-- Digital-activity (login) analysis.
--
-- Business questions addressed:
--   Q16  What proportion of login attempts fail?
--   Q17  Are failed logins concentrated by channel or customer?
--   Q18  Are customers logging in from countries other than their recorded one?
--
-- SQL concepts: aggregation, FILTER, JOIN, LEFT JOIN, GROUP BY, HAVING,
--               comparing two geography sources.
--
-- NOTE: login_events."timestamp" is a column name; it is quoted when needed.
-- A geography "mismatch" is an INDICATOR (travel, VPN, relocation are all
-- innocent explanations) — never treated as proof of compromise.
-- =============================================================================

\echo '--- 5.1 Overall login failure rate (Q16) --------------------------------'
SELECT
    count(*)                                              AS total_logins,
    count(*) FILTER (WHERE status = 'FAILED')             AS failed_logins,
    ROUND(100.0 * count(*) FILTER (WHERE status = 'FAILED')
                / count(*), 2)                            AS failure_rate_pct
FROM login_events;

\echo '--- 5.2 Login failure rate by channel (Q17) -----------------------------'
SELECT
    ch.channel_name,
    count(*)                                              AS total_logins,
    ROUND(100.0 * count(*) FILTER (WHERE l.status = 'FAILED')
                / count(*), 2)                            AS failure_rate_pct
FROM login_events l
JOIN channels ch ON ch.channel_id = l.channel_id
GROUP BY ch.channel_name
ORDER BY failure_rate_pct DESC;

\echo '--- 5.3 Customers with the most failed logins (Q17) ---------------------'
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name                    AS customer_name,
    count(*)                                              AS total_logins,
    count(*) FILTER (WHERE l.status = 'FAILED')           AS failed_logins,
    ROUND(100.0 * count(*) FILTER (WHERE l.status = 'FAILED')
                / count(*), 2)                            AS failure_rate_pct
FROM login_events l
JOIN customers c ON c.customer_id = l.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING count(*) >= 5                                       -- stable rate only
ORDER BY failed_logins DESC, failure_rate_pct DESC
LIMIT 15;

\echo '--- 5.4 Login geography vs recorded customer geography (Q18) -------------'
-- Compares login origin_country_id against the customer''s recorded country_id.
SELECT
    CASE
        WHEN l.origin_country_id IS NULL                  THEN 'unknown login origin'
        WHEN l.origin_country_id = c.country_id           THEN 'matches recorded country'
        ELSE                                                   'differs from recorded country'
    END                                                    AS geo_relationship,
    count(*)                                               AS login_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2)     AS pct_of_all
FROM login_events l
JOIN customers c ON c.customer_id = l.customer_id
GROUP BY geo_relationship
ORDER BY login_count DESC;

\echo '--- 5.5 Customers with the most geography-mismatched logins (Q18) --------'
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name                    AS customer_name,
    co.country_name                                       AS recorded_country,
    count(*) FILTER (WHERE l.origin_country_id IS NOT NULL
                       AND l.origin_country_id <> c.country_id) AS mismatched_logins,
    count(DISTINCT l.origin_country_id) FILTER (
        WHERE l.origin_country_id IS NOT NULL
          AND l.origin_country_id <> c.country_id)         AS distinct_foreign_countries
FROM login_events l
JOIN customers c  ON c.customer_id = l.customer_id
JOIN countries co ON co.country_id = c.country_id
GROUP BY c.customer_id, c.first_name, c.last_name, co.country_name
HAVING count(*) FILTER (WHERE l.origin_country_id IS NOT NULL
                          AND l.origin_country_id <> c.country_id) > 0
ORDER BY mismatched_logins DESC, distinct_foreign_countries DESC
LIMIT 15;
