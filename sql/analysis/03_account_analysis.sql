-- =============================================================================
-- 03_account_analysis.sql
-- Account-level activity and deviations from each account's own baseline.
--
-- Q10 How is activity distributed across accounts?
-- Q11 Which accounts are high-frequency senders?
-- Q12 Which individual payments sit far above an account's own history?
-- Q13 How does activity vary by account type and status?
--
-- SQL: window AVG/STDDEV OVER PARTITION BY, RANK, HAVING, JOIN.
-- =============================================================================

\echo '--- Q10 Account activity distribution -----------------------------------'
-- Business question: do a few accounts originate most payments?
-- Concepts: CTE, cumulative share (running total / grand total)
WITH acct AS (
    SELECT sender_account_id AS account_id, count(*) AS txn_count
    FROM transactions
    GROUP BY sender_account_id
)
SELECT
    count(*) AS accounts_with_txns,
    ROUND(AVG(txn_count), 1) AS mean_txn_count,
    ROUND(percentile_cont(0.50) WITHIN GROUP (ORDER BY txn_count)::numeric, 1) AS p50,
    ROUND(percentile_cont(0.90) WITHIN GROUP (ORDER BY txn_count)::numeric, 1) AS p90,
    MAX(txn_count) AS max_txn_count
FROM acct;

\echo '--- Q11 High-frequency accounts (mean + 3 stddev) -----------------------'
-- Business question: which sender accounts exceed the population frequency rule?
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
    a.customer_id,
    ac.txn_count,
    ROUND(s.mean_count, 1)                  AS population_mean,
    ROUND(s.mean_count + 3 * s.sd_count, 1) AS high_freq_threshold
FROM account_counts ac
JOIN accounts a ON a.account_id = ac.account_id
CROSS JOIN stats s
WHERE ac.txn_count > s.mean_count + 3 * s.sd_count
ORDER BY ac.txn_count DESC;

\echo '--- Q12 Payments far above the account''s own mean (window) -------------'
-- Business question: which payments are outliers *for that account*, not just
-- large in absolute terms?
-- Concepts: window functions partitioned by sender_account_id
-- Threshold: amount > account mean + 3 * account stddev, with >= 10 prior
-- observations so the baseline is not a tiny sample.
-- Limitation: a brand-new account cannot have a stable personal baseline.
WITH per_account AS (
    SELECT
        transaction_id,
        sender_account_id,
        sending_amount,
        created_at,
        AVG(sending_amount) OVER (PARTITION BY sender_account_id) AS acct_mean,
        STDDEV_POP(sending_amount) OVER (PARTITION BY sender_account_id) AS acct_sd,
        count(*) OVER (PARTITION BY sender_account_id) AS acct_txns
    FROM transactions
)
SELECT
    transaction_id,
    sender_account_id,
    sending_amount,
    ROUND(acct_mean, 2)               AS account_mean,
    ROUND(acct_mean + 3 * acct_sd, 2) AS account_threshold,
    created_at::date                  AS txn_date
FROM per_account
WHERE acct_txns >= 10
  AND acct_sd > 0
  AND sending_amount > acct_mean + 3 * acct_sd
ORDER BY sending_amount DESC
LIMIT 20;

\echo '--- Q13 Activity by account type and status -----------------------------'
-- Business question: do SAVINGS vs CURRENT vs CHECKING, or DORMANT vs ACTIVE,
-- differ in payment volume?
-- Concepts: JOIN, GROUP BY two dimensions
-- Implication: dormant/closed accounts originating payments would be an
-- operational-control flag; the CHECK on status does not prevent that.
SELECT
    a.account_type,
    a.status,
    count(DISTINCT a.account_id) AS n_accounts,
    count(t.transaction_id)      AS txn_count
FROM accounts a
LEFT JOIN transactions t ON t.sender_account_id = a.account_id
GROUP BY a.account_type, a.status
ORDER BY a.account_type, a.status;
