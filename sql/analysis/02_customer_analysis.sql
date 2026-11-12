-- =============================================================================
-- 02_customer_analysis.sql
-- Customer-level transaction behaviour.
--
-- Q06 What does typical customer frequency look like?
-- Q07 Which customers have unusually high transaction frequency?
-- Q08 Which customers transact unusually large aggregate value?
-- Q09 Which customers concentrate activity in a single channel?
--
-- SQL: JOIN through accounts, GROUP BY, HAVING, CTEs, STDDEV_POP, window
--      functions, ratio-to-total.
-- High frequency/value is an INDICATOR. A busy corporate-style account can be
-- legitimately high-volume.
-- =============================================================================

\echo '--- Q06 Customer frequency distribution ---------------------------------'
-- Business question: what is "normal" transaction count per customer?
-- Tables: transactions, accounts
-- Concepts: CTE, percentile_cont, AVG
WITH per_customer AS (
    SELECT a.customer_id, count(*) AS txn_count
    FROM transactions t
    JOIN accounts a ON a.account_id = t.sender_account_id
    GROUP BY a.customer_id
)
SELECT
    count(*) AS customers_with_txns,
    ROUND(AVG(txn_count), 1) AS mean_txn_count,
    ROUND(percentile_cont(0.50) WITHIN GROUP (ORDER BY txn_count)::numeric, 1) AS p50,
    ROUND(percentile_cont(0.90) WITHIN GROUP (ORDER BY txn_count)::numeric, 1) AS p90,
    ROUND(percentile_cont(0.99) WITHIN GROUP (ORDER BY txn_count)::numeric, 1) AS p99,
    MAX(txn_count) AS max_txn_count
FROM per_customer;

\echo '--- Q07 High-frequency customers (mean + 3 population stddev) -----------'
-- Business question: which customers sit in the extreme right tail of frequency?
-- Threshold: population mean + 3*stddev, a conventional descriptive outlier
-- rule (not a hypothesis test). Requires the customer to have transactions.
-- Limitation: stddev is sensitive to the injected high-frequency accounts.
WITH per_customer AS (
    SELECT
        a.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        count(*) AS txn_count
    FROM transactions t
    JOIN accounts a  ON a.account_id  = t.sender_account_id
    JOIN customers c ON c.customer_id = a.customer_id
    GROUP BY a.customer_id, c.first_name, c.last_name
),
stats AS (
    SELECT AVG(txn_count) AS mean_count, STDDEV_POP(txn_count) AS sd_count
    FROM per_customer
)
SELECT
    pc.customer_id,
    pc.customer_name,
    pc.txn_count,
    ROUND(s.mean_count, 1)                  AS population_mean,
    ROUND(s.mean_count + 3 * s.sd_count, 1) AS high_freq_threshold
FROM per_customer pc
CROSS JOIN stats s
WHERE pc.txn_count > s.mean_count + 3 * s.sd_count
ORDER BY pc.txn_count DESC;

\echo '--- Q08 Highest aggregate sending value by customer ----------------------'
-- Business question: who originates the most value (indicative, mixed FX)?
-- Concepts: SUM, ORDER BY, LIMIT
-- Limitation: summing mixed currencies overstates/understates true value.
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    count(*)                           AS txn_count,
    ROUND(SUM(t.sending_amount), 2)    AS total_sending_amount
FROM transactions t
JOIN accounts a  ON a.account_id  = t.sender_account_id
JOIN customers c ON c.customer_id = a.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_sending_amount DESC
LIMIT 15;

\echo '--- Q09 Channel concentration at customer level --------------------------'
-- Business question: do some customers route almost all activity through one
-- channel (e.g. only POS, only mobile)?
-- Concepts: CTE, ratio, HAVING
-- Implication: single-channel concentration is not inherently risky, but a
-- sudden change in channel mix (not measured here) would be a monitoring idea.
WITH cust_channel AS (
    SELECT
        a.customer_id,
        t.channel_id,
        count(*) AS n
    FROM transactions t
    JOIN accounts a ON a.account_id = t.sender_account_id
    GROUP BY a.customer_id, t.channel_id
),
cust_tot AS (
    SELECT customer_id, SUM(n) AS tot
    FROM cust_channel
    GROUP BY customer_id
)
SELECT
    cc.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    ch.channel_name,
    cc.n                               AS txn_on_top_channel,
    ct.tot                             AS total_txns,
    ROUND(100.0 * cc.n / ct.tot, 1)    AS pct_on_top_channel
FROM cust_channel cc
JOIN cust_tot ct ON ct.customer_id = cc.customer_id
JOIN customers c ON c.customer_id = cc.customer_id
JOIN channels ch ON ch.channel_id = cc.channel_id
WHERE ct.tot >= 15
  AND cc.n = (SELECT MAX(n) FROM cust_channel x WHERE x.customer_id = cc.customer_id)
  AND 1.0 * cc.n / ct.tot >= 0.80
ORDER BY pct_on_top_channel DESC, total_txns DESC
LIMIT 15;

\echo '--- Q09b Channel concentration at a 60% threshold (n >= 10) -------------'
-- The 80% / n>=15 rule returned no customers in this book. The same logic
-- at 60% / n>=10 is shown so the concentration technique is visible.
WITH cust_channel AS (
    SELECT a.customer_id, t.channel_id, count(*) AS n
    FROM transactions t
    JOIN accounts a ON a.account_id = t.sender_account_id
    GROUP BY a.customer_id, t.channel_id
),
cust_tot AS (
    SELECT customer_id, SUM(n) AS tot
    FROM cust_channel
    GROUP BY customer_id
)
SELECT
    cc.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    ch.channel_name,
    cc.n                            AS txn_on_top_channel,
    ct.tot                          AS total_txns,
    ROUND(100.0 * cc.n / ct.tot, 1) AS pct_on_top_channel
FROM cust_channel cc
JOIN cust_tot ct ON ct.customer_id = cc.customer_id
JOIN customers c ON c.customer_id = cc.customer_id
JOIN channels ch ON ch.channel_id = cc.channel_id
WHERE ct.tot >= 10
  AND cc.n = (SELECT MAX(n) FROM cust_channel x WHERE x.customer_id = cc.customer_id)
  AND 1.0 * cc.n / ct.tot >= 0.60
ORDER BY pct_on_top_channel DESC, total_txns DESC
LIMIT 15;
