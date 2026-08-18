-- =============================================================================
-- 06_combined_risk_indicators.sql
-- Combines transaction and digital-activity signals into a small set of
-- explainable, per-customer risk INDICATORS.
--
-- Business questions addressed:
--   Q19  Can transaction behaviour and digital activity be combined to give
--        better risk context?
--   Q20  Which customers trip several indicators at once?
--
-- METHODOLOGY (important, read before using the numbers):
--   * Each indicator is a plain BOOLEAN with an explicit, documented threshold.
--   * The composite is simply the COUNT of indicators a customer trips (0-5).
--   * There is NO arbitrary weighting and NO opaque "risk score". A higher count
--     means "more independent indicators are elevated for this customer", which
--     is a prompt to gather CONTEXT — not a determination of risk or wrongdoing.
--   * Every threshold below is a reviewable business rule, not a learned model.
--
-- INDICATOR DEFINITIONS
--   I1 elevated_txn_failure : txn_failure_rate > 2x the overall baseline,
--                             requiring >= 10 transactions (avoid small samples).
--   I2 elevated_login_failure: login_failure_rate > 25%, requiring >= 5 logins.
--   I3 high_cross_border     : cross-border share of transactions > 50%,
--                             requiring >= 10 transactions.
--   I4 has_high_value_txn    : at least one transaction at/above the 99th
--                             percentile of all sending amounts.
--   I5 geo_login_mismatch    : >= 3 logins from a country other than the
--                             customer's recorded country.
--
-- SQL concepts: multiple CTEs, LEFT JOIN, scalar subqueries, percentile_cont,
--               boolean-to-int casting, aggregate roll-up.
-- =============================================================================

\echo '--- 6.0 Baselines used by the indicators --------------------------------'
SELECT
    ROUND(100.0 * count(*) FILTER (WHERE status='FAILED') / count(*), 2) AS overall_txn_failure_pct,
    ROUND(percentile_cont(0.99) WITHIN GROUP (ORDER BY sending_amount)::numeric, 2)
                                                                          AS high_value_threshold_p99
FROM transactions;

-- Reusable indicator table, defined once via CTEs and reused by 6.1 and 6.2.
\echo '--- 6.1 Customers ranked by number of indicators tripped (Q19, Q20) ------'
WITH baseline AS (
    SELECT
        1.0 * count(*) FILTER (WHERE status='FAILED') / count(*)          AS txn_fail_base,
        percentile_cont(0.99) WITHIN GROUP (ORDER BY sending_amount)      AS high_value_p99
    FROM transactions
),
cust_txn AS (   -- transaction signals rolled up to the customer (via sender acct)
    SELECT
        a.customer_id,
        count(*)                                                          AS txn_count,
        count(*) FILTER (WHERE t.status='FAILED')                         AS failed_txn,
        count(*) FILTER (WHERE t.destination_country_id IS NOT NULL
                           AND t.destination_country_id <> t.origin_country_id) AS cross_border_txn,
        count(*) FILTER (WHERE t.sending_amount >= (SELECT high_value_p99 FROM baseline)) AS high_value_txn
    FROM transactions t
    JOIN accounts a ON a.account_id = t.sender_account_id
    GROUP BY a.customer_id
),
cust_login AS ( -- login signals rolled up to the customer
    SELECT
        l.customer_id,
        count(*)                                                          AS login_count,
        count(*) FILTER (WHERE l.status='FAILED')                         AS failed_login,
        count(*) FILTER (WHERE l.origin_country_id IS NOT NULL
                           AND l.origin_country_id <> c.country_id)       AS geo_mismatch_login
    FROM login_events l
    JOIN customers c ON c.customer_id = l.customer_id
    GROUP BY l.customer_id
),
indicators AS (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        COALESCE(ct.txn_count, 0)          AS txn_count,
        COALESCE(cl.login_count, 0)        AS login_count,
        ROUND(100.0 * ct.failed_txn   / NULLIF(ct.txn_count, 0), 1)   AS txn_failure_pct,
        ROUND(100.0 * cl.failed_login / NULLIF(cl.login_count, 0), 1) AS login_failure_pct,
        ROUND(100.0 * ct.cross_border_txn / NULLIF(ct.txn_count, 0), 1) AS cross_border_pct,
        COALESCE(ct.high_value_txn, 0)     AS high_value_txn,
        COALESCE(cl.geo_mismatch_login, 0) AS geo_mismatch_login,
        -- The five boolean indicators (documented in the header).
        -- COALESCE(..., false): a customer with no transactions/logins simply
        -- does not trip that indicator (rather than yielding NULL).
        COALESCE(ct.txn_count >= 10 AND 1.0 * ct.failed_txn / ct.txn_count
              > 2 * (SELECT txn_fail_base FROM baseline), false)       AS i1_elevated_txn_failure,
        COALESCE(cl.login_count >= 5 AND 1.0 * cl.failed_login / cl.login_count > 0.25, false) AS i2_elevated_login_failure,
        COALESCE(ct.txn_count >= 10 AND 1.0 * ct.cross_border_txn / ct.txn_count > 0.50, false) AS i3_high_cross_border,
        (COALESCE(ct.high_value_txn, 0) >= 1)                          AS i4_has_high_value_txn,
        (COALESCE(cl.geo_mismatch_login, 0) >= 3)                      AS i5_geo_login_mismatch
    FROM customers c
    LEFT JOIN cust_txn   ct ON ct.customer_id = c.customer_id
    LEFT JOIN cust_login cl ON cl.customer_id = c.customer_id
)
SELECT
    customer_id,
    customer_name,
    txn_count,
    txn_failure_pct,
    login_failure_pct,
    cross_border_pct,
    high_value_txn,
    geo_mismatch_login,
    -- Cast each boolean to 0/1 and sum -> transparent indicator count (0-5).
    (i1_elevated_txn_failure::int + i2_elevated_login_failure::int
   + i3_high_cross_border::int + i4_has_high_value_txn::int
   + i5_geo_login_mismatch::int)                                       AS indicators_tripped
FROM indicators
ORDER BY indicators_tripped DESC, txn_failure_pct DESC NULLS LAST
LIMIT 25;

\echo '--- 6.2 Distribution: how many customers trip N indicators --------------'
WITH baseline AS (
    SELECT
        1.0 * count(*) FILTER (WHERE status='FAILED') / count(*)     AS txn_fail_base,
        percentile_cont(0.99) WITHIN GROUP (ORDER BY sending_amount) AS high_value_p99
    FROM transactions
),
cust_txn AS (
    SELECT a.customer_id,
        count(*) AS txn_count,
        count(*) FILTER (WHERE t.status='FAILED') AS failed_txn,
        count(*) FILTER (WHERE t.destination_country_id IS NOT NULL
                           AND t.destination_country_id <> t.origin_country_id) AS cross_border_txn,
        count(*) FILTER (WHERE t.sending_amount >= (SELECT high_value_p99 FROM baseline)) AS high_value_txn
    FROM transactions t JOIN accounts a ON a.account_id = t.sender_account_id
    GROUP BY a.customer_id
),
cust_login AS (
    SELECT l.customer_id,
        count(*) AS login_count,
        count(*) FILTER (WHERE l.status='FAILED') AS failed_login,
        count(*) FILTER (WHERE l.origin_country_id IS NOT NULL
                           AND l.origin_country_id <> c.country_id) AS geo_mismatch_login
    FROM login_events l JOIN customers c ON c.customer_id = l.customer_id
    GROUP BY l.customer_id
),
scored AS (
    SELECT
        c.customer_id,
        (COALESCE(ct.txn_count >= 10 AND 1.0*ct.failed_txn/ct.txn_count > 2*(SELECT txn_fail_base FROM baseline), false)::int
       + COALESCE(cl.login_count >= 5 AND 1.0*cl.failed_login/cl.login_count > 0.25, false)::int
       + COALESCE(ct.txn_count >= 10 AND 1.0*ct.cross_border_txn/ct.txn_count > 0.50, false)::int
       + (COALESCE(ct.high_value_txn,0) >= 1)::int
       + (COALESCE(cl.geo_mismatch_login,0) >= 3)::int) AS indicators_tripped
    FROM customers c
    LEFT JOIN cust_txn   ct ON ct.customer_id = c.customer_id
    LEFT JOIN cust_login cl ON cl.customer_id = c.customer_id
)
SELECT
    indicators_tripped,
    count(*)                                              AS customer_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2)    AS pct_of_customers
FROM scored
GROUP BY indicators_tripped
ORDER BY indicators_tripped DESC;
