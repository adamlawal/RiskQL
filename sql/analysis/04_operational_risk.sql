-- =============================================================================
-- 04_operational_risk.sql
-- Operational-risk view: failures and activity across channels, types, branches
-- and time. Operational risk is the PRIMARY focus of the project.
--
-- Business questions addressed:
--   Q12  Which channels have the highest failure rates?
--   Q13  Are particular branches associated with unusual activity?
--   Q14  Are operational failures concentrated around particular periods?
--   Q15  Do outcomes differ across transaction types?
--
-- SQL concepts: aggregation, FILTER, JOIN/LEFT JOIN, date_trunc, HAVING,
--               window ranking.
-- =============================================================================

\echo '--- 4.1 Channel failure ranking (Q12) -----------------------------------'
SELECT
    ch.channel_name,
    count(*)                                              AS total_txns,
    count(*) FILTER (WHERE t.status = 'FAILED')           AS failed,
    count(*) FILTER (WHERE t.status = 'REVERSED')         AS reversed,
    count(*) FILTER (WHERE t.status = 'PENDING')          AS pending,
    ROUND(100.0 * count(*) FILTER (WHERE t.status = 'FAILED')
                / count(*), 2)                            AS failure_rate_pct
FROM transactions t
JOIN channels ch ON ch.channel_id = t.channel_id
GROUP BY ch.channel_name
ORDER BY failure_rate_pct DESC;

\echo '--- 4.2 Failure rate by transaction type (Q15) --------------------------'
SELECT
    tt.type_name,
    count(*)                                              AS total_txns,
    ROUND(100.0 * count(*) FILTER (WHERE t.status = 'FAILED')
                / count(*), 2)                            AS failure_rate_pct
FROM transactions t
JOIN transaction_types tt ON tt.type_id = t.transaction_type_id
GROUP BY tt.type_name
ORDER BY failure_rate_pct DESC;

\echo '--- 4.3 Branch activity: accounts opened & transaction volume (Q13) ------'
-- LEFT JOINs so branches with no accounts/transactions still appear (0, not
-- missing). Transaction volume is attributed to the SENDER account''s branch.
SELECT
    b.branch_id,
    b.branch_name,
    co.country_name                                       AS branch_country,
    count(DISTINCT a.account_id)                          AS accounts_opened,
    count(t.transaction_id)                               AS txns_sent,
    ROUND(100.0 * count(t.transaction_id) FILTER (WHERE t.status = 'FAILED')
              / NULLIF(count(t.transaction_id), 0), 2)    AS failure_rate_pct
FROM branches b
JOIN countries co ON co.country_id = b.country_id
LEFT JOIN accounts a ON a.branch_id = b.branch_id
LEFT JOIN transactions t ON t.sender_account_id = a.account_id
GROUP BY b.branch_id, b.branch_name, co.country_name
ORDER BY txns_sent DESC;

\echo '--- 4.4 Monthly failure rate by channel (Q14) ---------------------------'
-- Time x channel grid: helps spot a channel degrading in a particular period.
SELECT
    date_trunc('month', t.created_at)::date               AS month,
    ch.channel_name,
    count(*)                                              AS txns,
    ROUND(100.0 * count(*) FILTER (WHERE t.status = 'FAILED')
                / count(*), 2)                            AS failure_rate_pct
FROM transactions t
JOIN channels ch ON ch.channel_id = t.channel_id
GROUP BY 1, ch.channel_name
ORDER BY 1, ch.channel_name;

\echo '--- 4.5 Overall non-success outcomes summary ----------------------------'
SELECT
    count(*)                                                       AS total_txns,
    ROUND(100.0 * count(*) FILTER (WHERE status = 'FAILED')   / count(*), 2) AS failed_pct,
    ROUND(100.0 * count(*) FILTER (WHERE status = 'PENDING')  / count(*), 2) AS pending_pct,
    ROUND(100.0 * count(*) FILTER (WHERE status = 'REVERSED') / count(*), 2) AS reversed_pct
FROM transactions;
