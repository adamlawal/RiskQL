-- =============================================================================
-- 03_geographic_risk.sql
-- Geographic and cross-border transaction analysis.
--
-- Business questions addressed:
--   Q8   Which countries are most involved in transactions?
--   Q9   What proportion of transactions are cross-border?
--   Q10  Are failures concentrated in particular corridors (origin->dest)?
--   Q11  Is transaction volume geographically concentrated?
--
-- SQL concepts: JOINs, LEFT JOIN (destination may be NULL/external),
--               CASE, GROUP BY, HAVING, window functions for share-of-total.
--
-- DESIGN NOTE: geography is taken from explicit origin/destination country
-- columns. It is NEVER inferred from currency or from an account's country.
-- destination_country_id IS NULL means an external / unknown destination.
-- =============================================================================

\echo '--- 3.1 Transaction activity by ORIGIN country (Q8) ---------------------'
SELECT
    co.country_name                                       AS origin_country,
    count(*)                                              AS txn_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2)    AS pct_of_all
FROM transactions t
JOIN countries co ON co.country_id = t.origin_country_id
GROUP BY co.country_name
ORDER BY txn_count DESC;

\echo '--- 3.2 Cross-border proportion (Q9) ------------------------------------'
-- Cross-border = destination is known AND differs from origin.
-- External/unknown destination (NULL) is reported separately, not as domestic.
SELECT
    CASE
        WHEN destination_country_id IS NULL                     THEN 'external/unknown destination'
        WHEN destination_country_id = origin_country_id         THEN 'domestic'
        ELSE                                                         'cross-border'
    END                                                        AS geography,
    count(*)                                                    AS txn_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2)          AS pct_of_all
FROM transactions
GROUP BY geography
ORDER BY txn_count DESC;

\echo '--- 3.3 Top transaction corridors by volume (Q10) -----------------------'
SELECT
    co.country_name                                       AS origin_country,
    cd.country_name                                       AS destination_country,
    count(*)                                              AS txn_count,
    count(*) FILTER (WHERE t.status = 'FAILED')           AS failed_txns,
    ROUND(100.0 * count(*) FILTER (WHERE t.status = 'FAILED')
                / count(*), 2)                            AS failure_rate_pct
FROM transactions t
JOIN countries co ON co.country_id = t.origin_country_id
JOIN countries cd ON cd.country_id = t.destination_country_id  -- excludes NULL dest
WHERE t.origin_country_id <> t.destination_country_id          -- cross-border only
GROUP BY co.country_name, cd.country_name
ORDER BY txn_count DESC
LIMIT 15;

\echo '--- 3.4 Corridors with ELEVATED failure rates (Q10) ---------------------'
-- HAVING filters to corridors with enough volume AND an above-baseline failure
-- rate, so we do not react to a single failed transaction on a tiny corridor.
SELECT
    co.country_name                                       AS origin_country,
    cd.country_name                                       AS destination_country,
    count(*)                                              AS txn_count,
    ROUND(100.0 * count(*) FILTER (WHERE t.status = 'FAILED')
                / count(*), 2)                            AS failure_rate_pct
FROM transactions t
JOIN countries co ON co.country_id = t.origin_country_id
JOIN countries cd ON cd.country_id = t.destination_country_id
GROUP BY co.country_name, cd.country_name
HAVING count(*) >= 30
   AND 1.0 * count(*) FILTER (WHERE t.status = 'FAILED') / count(*) >
       (SELECT 1.0 * count(*) FILTER (WHERE status = 'FAILED') / count(*)
          FROM transactions)                              -- above overall baseline
ORDER BY failure_rate_pct DESC
LIMIT 15;

\echo '--- 3.5 Geographic concentration of volume (Q11) ------------------------'
-- Cumulative share shows how concentrated activity is across origin countries.
WITH by_country AS (
    SELECT origin_country_id, count(*) AS txn_count
    FROM transactions
    GROUP BY origin_country_id
)
SELECT
    co.country_name,
    bc.txn_count,
    ROUND(100.0 * bc.txn_count / SUM(bc.txn_count) OVER (), 2)          AS pct_of_all,
    ROUND(100.0 * SUM(bc.txn_count) OVER (ORDER BY bc.txn_count DESC)
                / SUM(bc.txn_count) OVER (), 2)                         AS cumulative_pct
FROM by_country bc
JOIN countries co ON co.country_id = bc.origin_country_id
ORDER BY bc.txn_count DESC;
