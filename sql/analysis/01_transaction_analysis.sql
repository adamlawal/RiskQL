-- =============================================================================
-- 01_transaction_analysis.sql
-- Descriptive analysis of transaction activity (the central analytical table).
--
-- Q01 What types of transactions occur most frequently?
-- Q02 What proportion of transactions fail, complete, pend, or reverse?
-- Q03 How is sending-amount distributed (including percentiles)?
-- Q04 How does volume and failure rate move over time?
-- Q05 Are sending vs receiving currencies often different?
--
-- SQL: aggregates, GROUP BY, ORDER BY, FILTER, window share, CASE, date_trunc,
--      percentile_cont.
-- Amounts are in the SENDING currency and are NOT FX-normalised, so totals
-- across currencies are indicative only.
-- =============================================================================

\echo '--- Q00 Dataset overview ------------------------------------------------'
-- Business question: how large is the activity window, and how many senders?
-- Tables: transactions
-- Concepts: COUNT, MIN/MAX, DISTINCT
-- Limitation: a single row is a payment attempt, including FAILED/PENDING.
SELECT
    count(*)                          AS total_transactions,
    count(DISTINCT sender_account_id) AS distinct_sender_accounts,
    (min(created_at) AT TIME ZONE 'UTC')::date AS first_txn_date_utc,
    (max(created_at) AT TIME ZONE 'UTC')::date AS last_txn_date_utc
FROM transactions;

\echo '--- Q01 Transactions by type --------------------------------------------'
-- Business question: which product types dominate volume?
-- Tables: transactions, transaction_types
-- Concepts: INNER JOIN, GROUP BY, window percentage
SELECT
    tt.type_name,
    count(*)                                           AS txn_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 1) AS pct_of_all
FROM transactions t
JOIN transaction_types tt ON tt.type_id = t.transaction_type_id
GROUP BY tt.type_name
ORDER BY txn_count DESC;

\echo '--- Q02 Status mix and overall failure rate -----------------------------'
-- Business question: what share of attempts fail vs complete?
-- Operational implication: the FAILED share is the headline operational-risk
-- rate; PENDING/REVERSED are also operational outcomes, not "success".
-- Limitation: a failed payment is not evidence of financial crime.
SELECT
    status,
    count(*)                                           AS txn_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2) AS pct_of_all
FROM transactions
GROUP BY status
ORDER BY txn_count DESC;

\echo '--- Q03 Sending-amount distribution (bands + percentiles) ---------------'
-- Business question: is value concentrated in small retail payments, or is
-- there a heavy tail of high-value transfers?
-- Concepts: CASE bucketing; percentile_cont (continuous percentile)
-- Interpretation: mean vs median (printed in the percentile query) shows skew.
SELECT
    CASE
        WHEN sending_amount < 100     THEN 'a. < 100'
        WHEN sending_amount < 1000    THEN 'b. 100 - 1k'
        WHEN sending_amount < 10000   THEN 'c. 1k - 10k'
        WHEN sending_amount < 100000  THEN 'd. 10k - 100k'
        ELSE                               'e. >= 100k'
    END                                                AS value_band,
    count(*)                                           AS txn_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2) AS pct_of_all
FROM transactions
GROUP BY value_band
ORDER BY value_band;

SELECT
    ROUND(AVG(sending_amount), 2)                                          AS mean_amount,
    ROUND(percentile_cont(0.50) WITHIN GROUP (ORDER BY sending_amount)::numeric, 2) AS p50_median,
    ROUND(percentile_cont(0.75) WITHIN GROUP (ORDER BY sending_amount)::numeric, 2) AS p75,
    ROUND(percentile_cont(0.90) WITHIN GROUP (ORDER BY sending_amount)::numeric, 2) AS p90,
    ROUND(percentile_cont(0.99) WITHIN GROUP (ORDER BY sending_amount)::numeric, 2) AS p99,
    ROUND(MAX(sending_amount), 2)                                          AS max_amount
FROM transactions;

\echo '--- Q04 Monthly volume and failure rate ---------------------------------'
-- Business question: are failures concentrated in particular months?
-- Concepts: date_trunc, FILTER
-- Limitation: synthetic data is generated across 2025; seasonal effects are
-- injected only weakly, so large month-to-month swings should be treated
-- cautiously.
SELECT
    date_trunc('month', created_at)::date AS month,
    count(*)                              AS txn_count,
    ROUND(100.0 * count(*) FILTER (WHERE status = 'FAILED') / count(*), 2)
                                          AS failure_rate_pct
FROM transactions
GROUP BY 1
ORDER BY 1;

\echo '--- Q05 Cross-currency vs same-currency payments ------------------------'
-- Business question: how often do sending and receiving currencies differ?
-- Limitation: currency difference is NOT a geographic fact. A USD account in
-- Lagos paying another USD account in London is same-currency and may still
-- be cross-border.
SELECT
    CASE
        WHEN sending_currency = receiving_currency THEN 'same currency'
        ELSE                                            'cross-currency'
    END                                                AS fx_shape,
    count(*)                                           AS txn_count,
    ROUND(100.0 * count(*) / SUM(count(*)) OVER (), 2) AS pct_of_all
FROM transactions
GROUP BY fx_shape
ORDER BY txn_count DESC;
