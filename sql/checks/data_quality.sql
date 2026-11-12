-- Data-quality validation for RiskQL.
--
--     psql "$DATABASE_URL" -f sql/checks/data_quality.sql
--
-- Each check returns (check_id, check_name, severity, issue_count, status).
-- On correctly loaded synthetic data, every row should be PASS (issue_count = 0).
-- Several rules are also table constraints; the checks still run explicitly so
-- they remain meaningful if data were loaded from a less-trusted source.

\echo '================ RiskQL DATA QUALITY REPORT ================'

WITH checks AS (
    SELECT 1 AS check_id,
           'PK uniqueness: transactions.transaction_id' AS check_name,
           'ERROR' AS severity,
           (SELECT count(*) FROM (
                SELECT transaction_id FROM transactions
                GROUP BY transaction_id HAVING count(*) > 1) d) AS issue_count
    UNION ALL
    SELECT 2, 'PK uniqueness: accounts.account_id', 'ERROR',
           (SELECT count(*) FROM (
                SELECT account_id FROM accounts GROUP BY account_id HAVING count(*) > 1) d)
    UNION ALL
    SELECT 3, 'PK uniqueness: customers.customer_id', 'ERROR',
           (SELECT count(*) FROM (
                SELECT customer_id FROM customers GROUP BY customer_id HAVING count(*) > 1) d)
    UNION ALL
    SELECT 4, 'PK uniqueness: login_events.login_id', 'ERROR',
           (SELECT count(*) FROM (
                SELECT login_id FROM login_events GROUP BY login_id HAVING count(*) > 1) d)

    UNION ALL
    SELECT 10, 'Missing required: transactions.status is NULL/blank', 'ERROR',
           (SELECT count(*) FROM transactions WHERE status IS NULL OR btrim(status) = '')
    UNION ALL
    SELECT 11, 'Missing required: transactions.created_at is NULL', 'ERROR',
           (SELECT count(*) FROM transactions WHERE created_at IS NULL)
    UNION ALL
    SELECT 12, 'Missing required: login_events.timestamp is NULL', 'ERROR',
           (SELECT count(*) FROM login_events WHERE "timestamp" IS NULL)
    UNION ALL
    SELECT 13, 'Missing required: customers.country_id is NULL', 'ERROR',
           (SELECT count(*) FROM customers WHERE country_id IS NULL)

    UNION ALL
    SELECT 20, 'Orphan FK: transaction.sender_account_id not in accounts', 'ERROR',
           (SELECT count(*) FROM transactions t
             LEFT JOIN accounts a ON a.account_id = t.sender_account_id
             WHERE a.account_id IS NULL)
    UNION ALL
    SELECT 21, 'Orphan FK: transaction.recipient_account_id not in accounts', 'ERROR',
           (SELECT count(*) FROM transactions t
             LEFT JOIN accounts a ON a.account_id = t.recipient_account_id
             WHERE t.recipient_account_id IS NOT NULL AND a.account_id IS NULL)
    UNION ALL
    SELECT 22, 'Orphan FK: account.customer_id not in customers', 'ERROR',
           (SELECT count(*) FROM accounts a
             LEFT JOIN customers c ON c.customer_id = a.customer_id
             WHERE c.customer_id IS NULL)
    UNION ALL
    SELECT 23, 'Orphan FK: login_events.customer_id not in customers', 'ERROR',
           (SELECT count(*) FROM login_events l
             LEFT JOIN customers c ON c.customer_id = l.customer_id
             WHERE c.customer_id IS NULL)
    UNION ALL
    SELECT 24, 'Orphan FK: origin/destination country invalid', 'ERROR',
           (SELECT count(*) FROM transactions t
             LEFT JOIN countries o ON o.country_id = t.origin_country_id
             LEFT JOIN countries d ON d.country_id = t.destination_country_id
             WHERE o.country_id IS NULL
                OR (t.destination_country_id IS NOT NULL AND d.country_id IS NULL))
    UNION ALL
    SELECT 25, 'Orphan FK: login origin_country_id invalid', 'ERROR',
           (SELECT count(*) FROM login_events l
             LEFT JOIN countries c ON c.country_id = l.origin_country_id
             WHERE l.origin_country_id IS NOT NULL AND c.country_id IS NULL)

    UNION ALL
    SELECT 30, 'Invalid amount: sending_amount <= 0', 'ERROR',
           (SELECT count(*) FROM transactions WHERE sending_amount <= 0)
    UNION ALL
    SELECT 31, 'Invalid amount: receiving_amount <= 0', 'ERROR',
           (SELECT count(*) FROM transactions WHERE receiving_amount <= 0)
    UNION ALL
    SELECT 32, 'Invalid exchange_rate: <= 0 when present', 'ERROR',
           (SELECT count(*) FROM transactions
             WHERE exchange_rate IS NOT NULL AND exchange_rate <= 0)
    UNION ALL
    SELECT 40, 'Invalid balance: current_balance < 0', 'ERROR',
           (SELECT count(*) FROM accounts WHERE current_balance < 0)

    UNION ALL
    SELECT 50, 'Invalid status: transactions.status', 'ERROR',
           (SELECT count(*) FROM transactions
             WHERE status NOT IN ('COMPLETED', 'FAILED', 'PENDING', 'REVERSED'))
    UNION ALL
    SELECT 51, 'Invalid status: accounts.status', 'ERROR',
           (SELECT count(*) FROM accounts
             WHERE status NOT IN ('ACTIVE', 'DORMANT', 'SUSPENDED', 'CLOSED'))
    UNION ALL
    SELECT 52, 'Invalid status: login_events.status', 'ERROR',
           (SELECT count(*) FROM login_events
             WHERE status NOT IN ('SUCCESS', 'FAILED'))

    UNION ALL
    SELECT 60, 'Invalid currency: sending/receiving code not 3 letters', 'ERROR',
           (SELECT count(*) FROM transactions
             WHERE sending_currency !~ '^[A-Z]{3}$'
                OR receiving_currency !~ '^[A-Z]{3}$')
    UNION ALL
    SELECT 61, 'Invalid currency: account currency_code not 3 letters', 'ERROR',
           (SELECT count(*) FROM accounts WHERE currency_code !~ '^[A-Z]{3}$')

    UNION ALL
    SELECT 70, 'Impossible: sender = recipient (self-transfer)', 'ERROR',
           (SELECT count(*) FROM transactions
             WHERE recipient_account_id IS NOT NULL
               AND recipient_account_id = sender_account_id)
    UNION ALL
    SELECT 71, 'Inconsistent: internal recipient missing XOR external_reference', 'ERROR',
           (SELECT count(*) FROM transactions
             WHERE NOT (
                (recipient_account_id IS NOT NULL AND external_reference IS NULL)
                OR (recipient_account_id IS NULL AND external_reference IS NOT NULL)
             ))
    UNION ALL
    SELECT 72, 'Inconsistent FX: cross-currency txn missing exchange_rate', 'WARN',
           (SELECT count(*) FROM transactions
             WHERE sending_currency <> receiving_currency
               AND exchange_rate IS NULL)
    UNION ALL
    SELECT 73, 'Inconsistent FX: same-currency txn has non-1 exchange_rate', 'WARN',
           (SELECT count(*) FROM transactions
             WHERE sending_currency = receiving_currency
               AND exchange_rate IS NOT NULL
               AND exchange_rate <> 1)

    UNION ALL
    SELECT 80, 'Duplicate business ref: external_reference repeated', 'WARN',
           (SELECT COALESCE(sum(cnt - 1), 0) FROM (
                SELECT external_reference, count(*) AS cnt
                  FROM transactions
                 WHERE external_reference IS NOT NULL
                 GROUP BY external_reference
                HAVING count(*) > 1) d)

    UNION ALL
    SELECT 90, 'Plausibility: customer date_of_birth in the future', 'ERROR',
           (SELECT count(*) FROM customers WHERE date_of_birth > CURRENT_DATE)
    UNION ALL
    SELECT 91, 'Plausibility: customer under 18 relative to 2025 activity window', 'WARN',
           (SELECT count(*) FROM customers WHERE date_of_birth > DATE '2007-01-01')
)
SELECT
    check_id,
    check_name,
    severity,
    issue_count,
    CASE WHEN issue_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM checks
ORDER BY (issue_count > 0) DESC, check_id;

\echo ''
\echo '---------------- SUMMARY ----------------'

SELECT
    count(*) FILTER (WHERE issue_count > 0 AND severity = 'ERROR') AS error_fail_count,
    count(*) FILTER (WHERE issue_count > 0 AND severity = 'WARN')  AS warn_fail_count,
    count(*) FILTER (WHERE issue_count = 0)                        AS pass_count,
    CASE
        WHEN count(*) FILTER (WHERE issue_count > 0 AND severity = 'ERROR') = 0
        THEN 'All ERROR-severity data-quality checks PASSED.'
        ELSE 'ERROR-severity issues found; investigate FAIL rows above.'
    END AS overall_status
FROM (
    SELECT 1 AS check_id, (SELECT count(*) FROM (SELECT transaction_id FROM transactions GROUP BY transaction_id HAVING count(*)>1) d) AS issue_count, 'ERROR' AS severity
    UNION ALL SELECT 2, (SELECT count(*) FROM (SELECT account_id FROM accounts GROUP BY account_id HAVING count(*)>1) d), 'ERROR'
    UNION ALL SELECT 3, (SELECT count(*) FROM (SELECT customer_id FROM customers GROUP BY customer_id HAVING count(*)>1) d), 'ERROR'
    UNION ALL SELECT 20, (SELECT count(*) FROM transactions t LEFT JOIN accounts a ON a.account_id=t.sender_account_id WHERE a.account_id IS NULL), 'ERROR'
    UNION ALL SELECT 30, (SELECT count(*) FROM transactions WHERE sending_amount <= 0 OR receiving_amount <= 0), 'ERROR'
    UNION ALL SELECT 40, (SELECT count(*) FROM accounts WHERE current_balance < 0), 'ERROR'
    UNION ALL SELECT 50, (SELECT count(*) FROM transactions WHERE status NOT IN ('COMPLETED','FAILED','PENDING','REVERSED')), 'ERROR'
    UNION ALL SELECT 70, (SELECT count(*) FROM transactions WHERE recipient_account_id = sender_account_id), 'ERROR'
    UNION ALL SELECT 71, (SELECT count(*) FROM transactions WHERE NOT (
                (recipient_account_id IS NOT NULL AND external_reference IS NULL)
                OR (recipient_account_id IS NULL AND external_reference IS NOT NULL))), 'ERROR'
) s;
