-- =============================================================================
-- 06_login_analysis.sql
-- Digital / authentication activity.
--
-- Q23 What is the overall login failure rate?
-- Q24 Are failed logins concentrated by channel?
-- Q25 Which customers show repeated failed attempts?
-- Q26 How often does login origin differ from recorded customer country?
--
-- IP-derived origin_country_id is approximate. A mismatch is an indicator,
-- not proof that the customer is physically in another country.
-- =============================================================================

\echo '--- Q23 Login status mix ------------------------------------------------'
-- Business question: what share of authentication attempts fail?
-- Tables: login_events
SELECT
    status,
    count(*)                                           AS login_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2) AS pct_of_all
FROM login_events
GROUP BY status
ORDER BY login_count DESC;

\echo '--- Q24 Login failure rate by channel -----------------------------------'
-- Business question: do self-service channels fail more than staffed ones?
SELECT
    ch.channel_name,
    count(*) AS total_logins,
    count(*) FILTER (WHERE l.status = 'FAILED') AS failed_logins,
    ROUND(100.0 * count(*) FILTER (WHERE l.status = 'FAILED') / count(*), 2)
             AS failure_rate_pct
FROM login_events l
JOIN channels ch ON ch.channel_id = l.channel_id
GROUP BY ch.channel_name
ORDER BY failure_rate_pct DESC;

\echo '--- Q25 Customers with repeated failed logins ---------------------------'
-- Business question: who has an elevated personal failure rate?
-- HAVING: at least 5 attempts so a single fail is not treated as a pattern.
-- Threshold: failure rate > 25%, a reviewable business rule, not a model.
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    count(*) AS login_count,
    count(*) FILTER (WHERE l.status = 'FAILED') AS failed_logins,
    ROUND(100.0 * count(*) FILTER (WHERE l.status = 'FAILED') / count(*), 1)
         AS failure_rate_pct
FROM login_events l
JOIN customers c ON c.customer_id = l.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING count(*) >= 5
   AND 1.0 * count(*) FILTER (WHERE l.status = 'FAILED') / count(*) > 0.25
ORDER BY failed_logins DESC, failure_rate_pct DESC
LIMIT 20;

\echo '--- Q26 Login geography vs recorded customer country --------------------'
-- Business question: are customers authenticating from a country other than
-- the one on their customer record?
-- Concepts: CASE, LEFT JOIN-equivalent CASE on NULL origin
SELECT
    CASE
        WHEN l.origin_country_id IS NULL        THEN 'unknown login origin'
        WHEN l.origin_country_id = c.country_id THEN 'matches recorded country'
        ELSE                                         'differs from recorded country'
    END                                                AS geo_relationship,
    count(*)                                           AS login_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2) AS pct_of_all
FROM login_events l
JOIN customers c ON c.customer_id = l.customer_id
GROUP BY geo_relationship
ORDER BY login_count DESC;

\echo '--- Q26b Customers with the most mismatched login origins ---------------'
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    co.country_name                    AS recorded_country,
    count(*) FILTER (
        WHERE l.origin_country_id IS NOT NULL
          AND l.origin_country_id <> c.country_id
    ) AS mismatched_logins,
    count(DISTINCT l.origin_country_id) FILTER (
        WHERE l.origin_country_id IS NOT NULL
          AND l.origin_country_id <> c.country_id
    ) AS distinct_foreign_countries
FROM login_events l
JOIN customers c  ON c.customer_id = l.customer_id
JOIN countries co ON co.country_id = c.country_id
GROUP BY c.customer_id, c.first_name, c.last_name, co.country_name
HAVING count(*) FILTER (
        WHERE l.origin_country_id IS NOT NULL
          AND l.origin_country_id <> c.country_id
    ) > 0
ORDER BY mismatched_logins DESC, distinct_foreign_countries DESC
LIMIT 15;
