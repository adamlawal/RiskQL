-- =============================================================================
-- 02_customer_risk.sql
-- Customer / account transaction-behaviour analysis.
--
-- Business questions addressed:
--   Q5  Which accounts/customers have unusually high transaction FREQUENCY?
--   Q6  Which accounts/customers have unusually high transaction VALUE?
--   Q7  Which transactions deviate strongly from an account's own norm?
--
-- SQL concepts: CTEs, window functions (AVG/STDDEV OVER, RANK), subqueries,
--               statistical thresholds (mean + k*stddev).
--
-- NOTE ON INTERPRETATION: high frequency or high value is an INDICATOR, not
-- proof of wrongdoing. A busy corporate account is legitimately high-frequency.
-- These queries surface accounts that WARRANT context, nothing more.
-- =============================================================================

\echo '--- 2.1 Most active accounts by transaction count (Q5) ------------------'
SELECT
    a.account_id,
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    count(*)                           AS txn_count,
    ROUND(SUM(t.sending_amount), 2)    AS total_sending_amount
FROM transactions t
JOIN accounts a  ON a.account_id  = t.sender_account_id
JOIN customers c ON c.customer_id = a.customer_id
GROUP BY a.account_id, c.customer_id, c.first_name, c.last_name
ORDER BY txn_count DESC
LIMIT 15;

\echo '--- 2.2 High-FREQUENCY indicator: accounts above mean + 3*stddev (Q5) ---'
-- Compute per-account counts, then compare each to the population mean/stddev.
WITH account_counts AS (
    SELECT sender_account_id AS account_id, count(*) AS txn_count
    FROM transactions
    GROUP BY sender_account_id
),
stats AS (
    SELECT AVG(txn_count) AS mean_count, STDDEV_POP(txn_count) AS sd_count
    FROM account_counts
)
SELECT
    ac.account_id,
    ac.txn_count,
    ROUND(s.mean_count, 1)                                 AS population_mean,
    ROUND(s.mean_count + 3 * s.sd_count, 1)                AS high_freq_threshold
FROM account_counts ac
CROSS JOIN stats s
WHERE ac.txn_count > s.mean_count + 3 * s.sd_count
ORDER BY ac.txn_count DESC;

\echo '--- 2.3 High-VALUE accounts: highest average & max transaction (Q6) ------'
SELECT
    t.sender_account_id                 AS account_id,
    count(*)                            AS txn_count,
    ROUND(AVG(t.sending_amount), 2)     AS avg_sending_amount,
    ROUND(MAX(t.sending_amount), 2)     AS max_sending_amount
FROM transactions t
GROUP BY t.sender_account_id
HAVING count(*) >= 5                    -- ignore tiny samples for a stable mean
ORDER BY avg_sending_amount DESC
LIMIT 15;

\echo '--- 2.4 Largest individual transactions (Q6) ----------------------------'
SELECT
    t.transaction_id,
    t.sender_account_id,
    tt.type_name,
    t.sending_amount,
    t.sending_currency,
    t.status,
    t.created_at::date AS txn_date
FROM transactions t
JOIN transaction_types tt ON tt.type_id = t.transaction_type_id
ORDER BY t.sending_amount DESC
LIMIT 15;

\echo '--- 2.5 Transactions far above their own account''s norm (Q7) -----------'
-- Window functions compute each account''s mean/stddev, then we flag single
-- transactions that exceed mean + 3*stddev FOR THAT ACCOUNT (personal baseline).
WITH per_account AS (
    SELECT
        transaction_id,
        sender_account_id,
        sending_amount,
        created_at,
        AVG(sending_amount)    OVER (PARTITION BY sender_account_id) AS acct_mean,
        STDDEV_POP(sending_amount) OVER (PARTITION BY sender_account_id) AS acct_sd,
        count(*)               OVER (PARTITION BY sender_account_id) AS acct_txns
    FROM transactions
)
SELECT
    transaction_id,
    sender_account_id,
    sending_amount,
    ROUND(acct_mean, 2)                       AS account_mean,
    ROUND(acct_mean + 3 * acct_sd, 2)         AS account_threshold,
    created_at::date                          AS txn_date
FROM per_account
WHERE acct_txns >= 10                          -- need a meaningful baseline
  AND acct_sd > 0
  AND sending_amount > acct_mean + 3 * acct_sd
ORDER BY sending_amount DESC
LIMIT 20;
