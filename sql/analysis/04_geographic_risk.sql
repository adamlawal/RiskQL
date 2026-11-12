-- =============================================================================
-- 04_geographic_risk.sql
-- Geographic and cross-border transaction analysis.
--
-- Q14 Which origin countries concentrate volume?
-- Q15 What share of payments are domestic vs cross-border vs unknown dest?
-- Q16 Which corridors carry the most volume and failures?
-- Q17 Which corridors have an elevated failure rate vs the book baseline?
--
-- DESIGN: geography is taken from explicit origin/destination columns.
-- It is NEVER inferred from currency or from an account's branch country.
-- destination_country_id IS NULL means external / unknown destination.
-- =============================================================================

\echo '--- Q14 Origin-country volume (with cumulative concentration) -----------'
-- Business question: how geographically concentrated is origination?
-- Concepts: window SUM for cumulative share (Pareto-style)
WITH by_country AS (
    SELECT origin_country_id, count(*) AS txn_count
    FROM transactions
    GROUP BY origin_country_id
)
SELECT
    co.country_name,
    bc.txn_count,
    ROUND(100.0 * bc.txn_count / SUM(bc.txn_count) OVER (), 2) AS pct_of_all,
    ROUND(
        100.0 * SUM(bc.txn_count) OVER (ORDER BY bc.txn_count DESC)
              / SUM(bc.txn_count) OVER (),
        2
    ) AS cumulative_pct
FROM by_country bc
JOIN countries co ON co.country_id = bc.origin_country_id
ORDER BY bc.txn_count DESC;

\echo '--- Q15 Domestic vs cross-border vs unknown destination -----------------'
-- Business question: what proportion of activity is cross-border?
-- NULL destination is reported separately, not labelled domestic.
SELECT
    CASE
        WHEN destination_country_id IS NULL             THEN 'external/unknown destination'
        WHEN destination_country_id = origin_country_id THEN 'domestic'
        ELSE                                                 'cross-border'
    END                                                AS geography,
    count(*)                                           AS txn_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2) AS pct_of_all
FROM transactions
GROUP BY geography
ORDER BY txn_count DESC;

\echo '--- Q16 Top cross-border corridors by volume ----------------------------'
-- Business question: which origin→destination pairs are the busiest?
-- Concepts: INNER JOIN on destination (drops NULL dest)
SELECT
    co.country_name AS origin_country,
    cd.country_name AS destination_country,
    count(*)        AS txn_count,
    count(*) FILTER (WHERE t.status = 'FAILED') AS failed_txns,
    ROUND(100.0 * count(*) FILTER (WHERE t.status = 'FAILED') / count(*), 2)
                    AS failure_rate_pct
FROM transactions t
JOIN countries co ON co.country_id = t.origin_country_id
JOIN countries cd ON cd.country_id = t.destination_country_id
WHERE t.origin_country_id <> t.destination_country_id
GROUP BY co.country_name, cd.country_name
ORDER BY txn_count DESC
LIMIT 15;

\echo '--- Q17 Corridors with elevated failure rates ---------------------------'
-- Business question: where are failures concentrated geographically?
-- HAVING: at least 30 payments so a handful of fails cannot dominate, AND
-- failure rate above the book-level baseline (scalar subquery).
-- Limitation: a higher rate can reflect correspondent-bank hours, FX, or
-- connectivity; it is an operational indicator, not a country-risk rating.
SELECT
    co.country_name AS origin_country,
    cd.country_name AS destination_country,
    count(*)        AS txn_count,
    ROUND(100.0 * count(*) FILTER (WHERE t.status = 'FAILED') / count(*), 2)
                    AS failure_rate_pct
FROM transactions t
JOIN countries co ON co.country_id = t.origin_country_id
JOIN countries cd ON cd.country_id = t.destination_country_id
GROUP BY co.country_name, cd.country_name
HAVING count(*) >= 30
   AND 1.0 * count(*) FILTER (WHERE t.status = 'FAILED') / count(*) >
       (SELECT 1.0 * count(*) FILTER (WHERE status = 'FAILED') / count(*)
          FROM transactions)
ORDER BY failure_rate_pct DESC
LIMIT 15;
