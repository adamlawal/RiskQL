-- =============================================================================
-- 01_transaction_analysis.sql
-- Descriptive analysis of transaction activity.
--
-- Business questions addressed:
--   Q1  What types of transactions occur most frequently?
--   Q2  What proportion of transactions fail?
--   Q3  Are failed transactions concentrated by type or channel?
--   Q4  How is transaction value distributed?
--
-- SQL concepts: aggregate functions, GROUP BY, ORDER BY, COUNT(*) FILTER,
--               ROUND, CASE bucketing, date_trunc.
-- All amounts below are expressed in the SENDING currency and are NOT converted
-- to a single currency, so cross-currency totals are indicative only.
-- =============================================================================

\echo '--- 1.0 Dataset overview -------------------------------------------------'
SELECT
    count(*)                         AS total_transactions,
    count(DISTINCT sender_account_id) AS distinct_sender_accounts,
    min(created_at)::date            AS first_txn_date,
    max(created_at)::date            AS last_txn_date
FROM transactions;

\echo '--- 1.1 Transactions by type (Q1) ---------------------------------------'
SELECT
    tt.type_name,
    count(*)                                             AS txn_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 1)   AS pct_of_all
FROM transactions t
JOIN transaction_types tt ON tt.type_id = t.transaction_type_id
GROUP BY tt.type_name
ORDER BY txn_count DESC;

\echo '--- 1.2 Overall status breakdown & failure rate (Q2) --------------------'
SELECT
    status,
    count(*)                                           AS txn_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2) AS pct_of_all
FROM transactions
GROUP BY status
ORDER BY txn_count DESC;

\echo '--- 1.3 Failure rate by channel (Q3) ------------------------------------'
-- FILTER lets us count only failed rows within the same aggregate pass.
SELECT
    ch.channel_name,
    count(*)                                                        AS total_txns,
    count(*) FILTER (WHERE t.status = 'FAILED')                     AS failed_txns,
    ROUND(100.0 * count(*) FILTER (WHERE t.status = 'FAILED')
                / count(*), 2)                                      AS failure_rate_pct
FROM transactions t
JOIN channels ch ON ch.channel_id = t.channel_id
GROUP BY ch.channel_name
ORDER BY failure_rate_pct DESC;

\echo '--- 1.4 Failure rate by transaction type (Q3) ---------------------------'
SELECT
    tt.type_name,
    count(*)                                                        AS total_txns,
    count(*) FILTER (WHERE t.status = 'FAILED')                     AS failed_txns,
    ROUND(100.0 * count(*) FILTER (WHERE t.status = 'FAILED')
                / count(*), 2)                                      AS failure_rate_pct
FROM transactions t
JOIN transaction_types tt ON tt.type_id = t.transaction_type_id
GROUP BY tt.type_name
ORDER BY failure_rate_pct DESC;

\echo '--- 1.5 Monthly transaction volume & failure rate (trend) ---------------'
SELECT
    date_trunc('month', created_at)::date                          AS month,
    count(*)                                                        AS txn_count,
    ROUND(100.0 * count(*) FILTER (WHERE status = 'FAILED')
                / count(*), 2)                                      AS failure_rate_pct
FROM transactions
GROUP BY 1
ORDER BY 1;

\echo '--- 1.6 Transaction value distribution buckets (Q4) ---------------------'
-- CASE puts each transaction into a value band (sending currency, indicative).
SELECT
    CASE
        WHEN sending_amount <  100    THEN 'a. < 100'
        WHEN sending_amount <  1000   THEN 'b. 100 - 1k'
        WHEN sending_amount <  10000  THEN 'c. 1k - 10k'
        WHEN sending_amount <  100000 THEN 'd. 10k - 100k'
        ELSE                               'e. >= 100k'
    END                                                            AS value_band,
    count(*)                                                        AS txn_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2)              AS pct_of_all
FROM transactions
GROUP BY value_band
ORDER BY value_band;
