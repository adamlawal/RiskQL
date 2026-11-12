-- =============================================================================
-- 07_combined_risk_indicators.sql
-- Combines digital activity and transaction activity.
--
-- Q27 Did clustered failed logins precede unusual transaction activity?
-- Q28 Is transaction origin inconsistent with recent successful login geography?
-- Q29 Which customers trip several transparent indicators at once?
--
-- METHODOLOGY
--   * Each indicator is a documented boolean with an explicit threshold.
--   * The composite is the COUNT of indicators tripped (0–5). There is no
--     learned weight and no opaque score.
--   * A higher count means "more independent indicators are elevated": a
--     prompt to gather context, not a determination of misconduct.
--
-- INDICATORS
--   I1 elevated_txn_failure  : txn failure rate > 2× book baseline, n >= 10
--   I2 elevated_login_failure: login failure rate > 25%, n >= 5
--   I3 high_cross_border     : cross-border share > 50%, n >= 10
--   I4 has_high_value_txn    : at least one sending_amount >= book P99
--   I5 geo_login_mismatch    : >= 3 logins from a country other than recorded
-- =============================================================================

\echo '--- Q27 Failed logins followed by a high-value payment within 24h -------'
-- Business question: are authentication failures followed closely by unusual
-- payments for the same customer?
-- Logic: for each customer, find a FAILED login and a later transaction from
-- one of their accounts within 24 hours whose amount is >= book P99.
-- Concepts: JOIN on customer via accounts, time interval, percentile subquery.
-- Limitation: temporal proximity is not causation. Travel, payroll, and
-- mistyped passwords next to a planned remittance all look similar.
WITH p99 AS (
    SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY sending_amount) AS thr
    FROM transactions
)
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    count(DISTINCT t.transaction_id)   AS high_value_txns_after_fail,
    min(t.created_at)                  AS first_follow_on_txn,
    max(l."timestamp")                 AS last_failed_login_before
FROM login_events l
JOIN customers c ON c.customer_id = l.customer_id
JOIN accounts a  ON a.customer_id = c.customer_id
JOIN transactions t ON t.sender_account_id = a.account_id
CROSS JOIN p99
WHERE l.status = 'FAILED'
  AND t.created_at > l."timestamp"
  AND t.created_at <= l."timestamp" + INTERVAL '24 hours'
  AND t.sending_amount >= p99.thr
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY high_value_txns_after_fail DESC, first_follow_on_txn
LIMIT 20;

\echo '--- Q28 Payments whose origin country differs from the latest success login'
-- Business question: does the payment's origin_country_id disagree with the
-- most recent successful login origin for that customer (within 7 days)?
-- Concepts: DISTINCT ON (Postgres) to pick the latest prior successful login.
-- Limitation: geo-IP is coarse; a VPN or corporate gateway can create a
-- mismatch with no travel at all.
WITH prior_login AS (
    SELECT DISTINCT ON (t.transaction_id)
        t.transaction_id,
        t.origin_country_id AS txn_origin,
        l.origin_country_id AS login_origin,
        l."timestamp"       AS login_time,
        t.created_at        AS txn_time,
        a.customer_id
    FROM transactions t
    JOIN accounts a ON a.account_id = t.sender_account_id
    JOIN login_events l ON l.customer_id = a.customer_id
    WHERE l.status = 'SUCCESS'
      AND l.origin_country_id IS NOT NULL
      AND l."timestamp" <= t.created_at
      AND l."timestamp" >= t.created_at - INTERVAL '7 days'
    ORDER BY t.transaction_id, l."timestamp" DESC
)
SELECT
    co.country_name AS payment_origin_country,
    cl.country_name AS latest_success_login_country,
    count(*)        AS txn_count
FROM prior_login p
JOIN countries co ON co.country_id = p.txn_origin
JOIN countries cl ON cl.country_id = p.login_origin
WHERE p.txn_origin <> p.login_origin
GROUP BY 1, 2
ORDER BY txn_count DESC
LIMIT 15;

\echo '--- Q28b Share of payments whose origin disagrees with recent login -----'
WITH prior_login AS (
    SELECT DISTINCT ON (t.transaction_id)
        t.transaction_id,
        t.origin_country_id AS txn_origin,
        l.origin_country_id AS login_origin
    FROM transactions t
    JOIN accounts a ON a.account_id = t.sender_account_id
    JOIN login_events l ON l.customer_id = a.customer_id
    WHERE l.status = 'SUCCESS'
      AND l.origin_country_id IS NOT NULL
      AND l."timestamp" <= t.created_at
      AND l."timestamp" >= t.created_at - INTERVAL '7 days'
    ORDER BY t.transaction_id, l."timestamp" DESC
)
SELECT
    count(*) AS txns_with_recent_success_login,
    count(*) FILTER (WHERE txn_origin <> login_origin) AS origin_mismatch_txns,
    ROUND(
        100.0 * count(*) FILTER (WHERE txn_origin <> login_origin) / count(*),
        2
    ) AS mismatch_pct
FROM prior_login;

\echo '--- Q29 Indicator baselines ---------------------------------------------'
SELECT
    ROUND(100.0 * count(*) FILTER (WHERE status = 'FAILED') / count(*), 2)
        AS overall_txn_failure_pct,
    ROUND(percentile_cont(0.99) WITHIN GROUP (ORDER BY sending_amount)::numeric, 2)
        AS high_value_threshold_p99
FROM transactions;

\echo '--- Q29b Customers ranked by indicators tripped -------------------------'
WITH baseline AS (
    SELECT
        1.0 * count(*) FILTER (WHERE status = 'FAILED') / count(*) AS txn_fail_base,
        percentile_cont(0.99) WITHIN GROUP (ORDER BY sending_amount) AS high_value_p99
    FROM transactions
),
cust_txn AS (
    SELECT
        a.customer_id,
        count(*) AS txn_count,
        count(*) FILTER (WHERE t.status = 'FAILED') AS failed_txn,
        count(*) FILTER (
            WHERE t.destination_country_id IS NOT NULL
              AND t.destination_country_id <> t.origin_country_id
        ) AS cross_border_txn,
        count(*) FILTER (
            WHERE t.sending_amount >= (SELECT high_value_p99 FROM baseline)
        ) AS high_value_txn
    FROM transactions t
    JOIN accounts a ON a.account_id = t.sender_account_id
    GROUP BY a.customer_id
),
cust_login AS (
    SELECT
        l.customer_id,
        count(*) AS login_count,
        count(*) FILTER (WHERE l.status = 'FAILED') AS failed_login,
        count(*) FILTER (
            WHERE l.origin_country_id IS NOT NULL
              AND l.origin_country_id <> c.country_id
        ) AS geo_mismatch_login
    FROM login_events l
    JOIN customers c ON c.customer_id = l.customer_id
    GROUP BY l.customer_id
),
indicators AS (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        COALESCE(ct.txn_count, 0) AS txn_count,
        COALESCE(cl.login_count, 0) AS login_count,
        ROUND(100.0 * ct.failed_txn / NULLIF(ct.txn_count, 0), 1) AS txn_failure_pct,
        ROUND(100.0 * cl.failed_login / NULLIF(cl.login_count, 0), 1) AS login_failure_pct,
        ROUND(100.0 * ct.cross_border_txn / NULLIF(ct.txn_count, 0), 1) AS cross_border_pct,
        COALESCE(ct.high_value_txn, 0) AS high_value_txn,
        COALESCE(cl.geo_mismatch_login, 0) AS geo_mismatch_login,
        COALESCE(
            ct.txn_count >= 10
            AND 1.0 * ct.failed_txn / ct.txn_count > 2 * (SELECT txn_fail_base FROM baseline),
            false
        ) AS i1_elevated_txn_failure,
        COALESCE(
            cl.login_count >= 5
            AND 1.0 * cl.failed_login / cl.login_count > 0.25,
            false
        ) AS i2_elevated_login_failure,
        COALESCE(
            ct.txn_count >= 10
            AND 1.0 * ct.cross_border_txn / ct.txn_count > 0.50,
            false
        ) AS i3_high_cross_border,
        (COALESCE(ct.high_value_txn, 0) >= 1) AS i4_has_high_value_txn,
        (COALESCE(cl.geo_mismatch_login, 0) >= 3) AS i5_geo_login_mismatch
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
    (
        i1_elevated_txn_failure::int
        + i2_elevated_login_failure::int
        + i3_high_cross_border::int
        + i4_has_high_value_txn::int
        + i5_geo_login_mismatch::int
    ) AS indicators_tripped
FROM indicators
ORDER BY indicators_tripped DESC, txn_failure_pct DESC NULLS LAST
LIMIT 25;

\echo '--- Q29c Distribution of indicator counts -------------------------------'
WITH baseline AS (
    SELECT
        1.0 * count(*) FILTER (WHERE status = 'FAILED') / count(*) AS txn_fail_base,
        percentile_cont(0.99) WITHIN GROUP (ORDER BY sending_amount) AS high_value_p99
    FROM transactions
),
cust_txn AS (
    SELECT
        a.customer_id,
        count(*) AS txn_count,
        count(*) FILTER (WHERE t.status = 'FAILED') AS failed_txn,
        count(*) FILTER (
            WHERE t.destination_country_id IS NOT NULL
              AND t.destination_country_id <> t.origin_country_id
        ) AS cross_border_txn,
        count(*) FILTER (
            WHERE t.sending_amount >= (SELECT high_value_p99 FROM baseline)
        ) AS high_value_txn
    FROM transactions t
    JOIN accounts a ON a.account_id = t.sender_account_id
    GROUP BY a.customer_id
),
cust_login AS (
    SELECT
        l.customer_id,
        count(*) AS login_count,
        count(*) FILTER (WHERE l.status = 'FAILED') AS failed_login,
        count(*) FILTER (
            WHERE l.origin_country_id IS NOT NULL
              AND l.origin_country_id <> c.country_id
        ) AS geo_mismatch_login
    FROM login_events l
    JOIN customers c ON c.customer_id = l.customer_id
    GROUP BY l.customer_id
),
scored AS (
    SELECT
        c.customer_id,
        (
            COALESCE(
                ct.txn_count >= 10
                AND 1.0 * ct.failed_txn / ct.txn_count
                    > 2 * (SELECT txn_fail_base FROM baseline),
                false
            )::int
            + COALESCE(
                cl.login_count >= 5
                AND 1.0 * cl.failed_login / cl.login_count > 0.25,
                false
            )::int
            + COALESCE(
                ct.txn_count >= 10
                AND 1.0 * ct.cross_border_txn / ct.txn_count > 0.50,
                false
            )::int
            + (COALESCE(ct.high_value_txn, 0) >= 1)::int
            + (COALESCE(cl.geo_mismatch_login, 0) >= 3)::int
        ) AS indicators_tripped
    FROM customers c
    LEFT JOIN cust_txn   ct ON ct.customer_id = c.customer_id
    LEFT JOIN cust_login cl ON cl.customer_id = c.customer_id
)
SELECT
    indicators_tripped,
    count(*) AS customer_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2) AS pct_of_customers
FROM scored
GROUP BY indicators_tripped
ORDER BY indicators_tripped DESC;
