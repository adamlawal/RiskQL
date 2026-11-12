-- =============================================================================
-- 05_operational_risk.sql
-- Primary project focus: operational outcomes across channels, types, branches,
-- and time.
--
-- Q18 Which channels have the highest failure rates?
-- Q19 Do outcomes differ by transaction type?
-- Q20 Are particular branches associated with unusual origination volume?
-- Q21 Are failures concentrated by hour of day or day of week?
-- Q22 How does a 7-day rolling failure rate evolve?
-- =============================================================================

\echo '--- Q18 Channel volume and failure ranking ------------------------------'
-- Business question: which channels fail most often?
-- Concepts: FILTER, JOIN, ORDER BY rate
-- Interpretation: POS and internet banking were generated with higher baseline
-- fail probabilities; branch was generated lowest. The query should recover
-- that operational pattern.
SELECT
    ch.channel_name,
    count(*) AS total_txns,
    count(*) FILTER (WHERE t.status = 'FAILED') AS failed_txns,
    ROUND(100.0 * count(*) FILTER (WHERE t.status = 'FAILED') / count(*), 2)
             AS failure_rate_pct
FROM transactions t
JOIN channels ch ON ch.channel_id = t.channel_id
GROUP BY ch.channel_name
ORDER BY failure_rate_pct DESC;

\echo '--- Q19 Failure rate by transaction type --------------------------------'
-- Business question: do remittances fail more than domestic transfers?
SELECT
    tt.type_name,
    count(*) AS total_txns,
    count(*) FILTER (WHERE t.status = 'FAILED') AS failed_txns,
    ROUND(100.0 * count(*) FILTER (WHERE t.status = 'FAILED') / count(*), 2)
             AS failure_rate_pct
FROM transactions t
JOIN transaction_types tt ON tt.type_id = t.transaction_type_id
GROUP BY tt.type_name
ORDER BY failure_rate_pct DESC;

\echo '--- Q20 Branch origination volume vs share of book ----------------------'
-- Business question: are a few branches associated with outsized activity?
-- Join path: transaction → sender account → branch.
-- Limitation: this is origination volume, not a branch operational-loss event.
SELECT
    b.branch_name,
    co.country_name,
    count(*) AS txn_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2) AS pct_of_all
FROM transactions t
JOIN accounts a   ON a.account_id = t.sender_account_id
JOIN branches b   ON b.branch_id  = a.branch_id
JOIN countries co ON co.country_id = b.country_id
GROUP BY b.branch_name, co.country_name
ORDER BY txn_count DESC;

\echo '--- Q21 Failures by hour (UTC) and weekday ------------------------------'
-- Business question: do operational failures cluster in particular periods?
-- Concepts: EXTRACT, FILTER
-- Limitation: timestamps are UTC; local-time peaks in Lagos vs New York will
-- not line up. Treat this as a book-level clock, not a branch clock.
SELECT
    EXTRACT(HOUR FROM created_at)::int AS hour_utc,
    count(*) AS txn_count,
    ROUND(100.0 * count(*) FILTER (WHERE status = 'FAILED') / count(*), 2)
           AS failure_rate_pct
FROM transactions
GROUP BY 1
ORDER BY 1;

SELECT
    TO_CHAR(created_at, 'Dy') AS weekday,
    EXTRACT(ISODOW FROM created_at)::int AS isodow,
    count(*) AS txn_count,
    ROUND(100.0 * count(*) FILTER (WHERE status = 'FAILED') / count(*), 2)
           AS failure_rate_pct
FROM transactions
GROUP BY 1, 2
ORDER BY 2;

\echo '--- Q22 Seven-day rolling failure rate ----------------------------------'
-- Business question: is the operational failure rate stable or drifting?
-- Concepts: daily grain, then SUM() OVER (ROWS BETWEEN 6 PRECEDING AND CURRENT)
-- Limitation: the first 6 days of the window are partial rolling windows.
WITH daily AS (
    SELECT
        created_at::date AS d,
        count(*) AS n,
        count(*) FILTER (WHERE status = 'FAILED') AS f
    FROM transactions
    GROUP BY 1
)
SELECT
    d,
    n AS txn_count,
    ROUND(100.0 * f / n, 2) AS daily_fail_pct,
    SUM(n) OVER (ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS n_7d,
    ROUND(
        100.0 * SUM(f) OVER (ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
              / SUM(n) OVER (ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),
        2
    ) AS fail_pct_7d
FROM daily
ORDER BY d;
