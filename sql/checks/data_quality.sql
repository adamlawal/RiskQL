-- =============================================================================
-- data_quality.sql
-- Data-quality validation for the RiskQL database.
--
-- Run (from repo root):
--     psql "$DATABASE_URL" -f sql/checks/data_quality.sql
--
-- HOW TO READ THE OUTPUT
-- Each check returns one row: (check_id, check_name, severity, issue_count,
-- status). On correctly loaded data every check should show issue_count = 0 and
-- status = 'PASS'. Any 'FAIL' row means that check found records that violate
-- the stated rule; the check_name explains what to investigate.
--
-- Several of these rules are also enforced by table constraints (PK, FK, CHECK).
-- The checks are still written explicitly so they remain meaningful if a
-- constraint were ever relaxed, or if data were loaded from a less-trusted
-- source (staging). They demonstrate HOW you would validate the data, not just
-- trust that the constraints held.
-- =============================================================================

\echo '================ RiskQL DATA QUALITY REPORT ================'

WITH checks AS (

    -- ---- 1. Primary-key uniqueness -----------------------------------------
    SELECT 1 AS check_id,
           'PK uniqueness: transactions.transaction_id' AS check_name,
           'ERROR' AS severity,
           (SELECT count(*) FROM (
                SELECT transaction_id FROM transactions
                GROUP BY transaction_id HAVING count(*) > 1) d) AS issue_count

    UNION ALL
    SELECT 2, 'PK uniqueness: accounts.account_id', 'ERROR',
           (SELECT count(*) FROM (
                SELECT account_id FROM accounts
                GROUP BY account_id HAVING count(*) > 1) d)

    UNION ALL
    SELECT 3, 'PK uniqueness: customers.customer_id', 'ERROR',
           (SELECT count(*) FROM (
                SELECT customer_id FROM customers
                GROUP BY customer_id HAVING count(*) > 1) d)

    -- ---- 2. Missing required business values -------------------------------
    UNION ALL
    SELECT 10, 'Missing required: transactions.status is NULL/blank', 'ERROR',
           (SELECT count(*) FROM transactions
             WHERE status IS NULL OR btrim(status) = '')

    UNION ALL
    SELECT 11, 'Missing required: accounts.currency_code is NULL/blank', 'ERROR',
           (SELECT count(*) FROM accounts
             WHERE currency_code IS NULL OR btrim(currency_code) = '')

    UNION ALL
    SELECT 12, 'Missing required: customers.country_id is NULL', 'ERROR',
           (SELECT count(*) FROM customers WHERE country_id IS NULL)

    -- ---- 3. Orphaned foreign keys (referential integrity) ------------------
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
    SELECT 24, 'Orphan FK: transaction origin/destination country invalid', 'ERROR',
           (SELECT count(*) FROM transactions t
             LEFT JOIN countries o ON o.country_id = t.origin_country_id
             LEFT JOIN countries d ON d.country_id = t.destination_country_id
             WHERE o.country_id IS NULL
                OR (t.destination_country_id IS NOT NULL AND d.country_id IS NULL))

    -- ---- 4. Invalid transaction amounts ------------------------------------
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

    -- ---- 5. Invalid account balances ---------------------------------------
    UNION ALL
    SELECT 40, 'Invalid balance: current_balance < 0', 'ERROR',
           (SELECT count(*) FROM accounts WHERE current_balance < 0)

    -- ---- 6. Invalid statuses (outside allowed domain) ----------------------
    UNION ALL
    SELECT 50, 'Invalid status: transactions.status not in allowed set', 'ERROR',
           (SELECT count(*) FROM transactions
             WHERE status NOT IN ('COMPLETED', 'FAILED', 'PENDING', 'REVERSED'))

    UNION ALL
    SELECT 51, 'Invalid status: accounts.status not in allowed set', 'ERROR',
           (SELECT count(*) FROM accounts
             WHERE status NOT IN ('ACTIVE', 'DORMANT', 'SUSPENDED', 'CLOSED'))

    UNION ALL
    SELECT 52, 'Invalid status: login_events.status not in allowed set', 'ERROR',
           (SELECT count(*) FROM login_events
             WHERE status NOT IN ('SUCCESS', 'FAILED'))

    -- ---- 7. Invalid currency codes -----------------------------------------
    UNION ALL
    SELECT 60, 'Invalid currency: sending/receiving code not 3 letters', 'ERROR',
           (SELECT count(*) FROM transactions
             WHERE sending_currency !~ '^[A-Z]{3}$'
                OR receiving_currency !~ '^[A-Z]{3}$')

    UNION ALL
    SELECT 61, 'Invalid currency: account currency_code not 3 letters', 'ERROR',
           (SELECT count(*) FROM accounts WHERE currency_code !~ '^[A-Z]{3}$')

    -- ---- 8./9. Impossible relationships ------------------------------------
    UNION ALL
    SELECT 70, 'Impossible: transaction sender = recipient (self-transfer)', 'ERROR',
           (SELECT count(*) FROM transactions
             WHERE recipient_account_id IS NOT NULL
               AND recipient_account_id = sender_account_id)

    UNION ALL
    SELECT 71, 'Inconsistent FX: cross-currency txn missing exchange_rate', 'WARN',
           (SELECT count(*) FROM transactions
             WHERE sending_currency <> receiving_currency
               AND exchange_rate IS NULL)

    UNION ALL
    SELECT 72, 'Inconsistent FX: same-currency txn has non-1 exchange_rate', 'WARN',
           (SELECT count(*) FROM transactions
             WHERE sending_currency = receiving_currency
               AND exchange_rate IS NOT NULL
               AND exchange_rate <> 1)

    -- ---- 10. Duplicate business references ---------------------------------
    UNION ALL
    SELECT 80, 'Duplicate business ref: external_reference repeated', 'WARN',
           (SELECT COALESCE(sum(cnt - 1), 0) FROM (
                SELECT external_reference, count(*) AS cnt
                  FROM transactions
                 WHERE external_reference IS NOT NULL
                 GROUP BY external_reference
                HAVING count(*) > 1) d)

    -- ---- Data-profile / plausibility ---------------------------------------
    UNION ALL
    SELECT 90, 'Plausibility: customer date_of_birth in the future', 'ERROR',
           (SELECT count(*) FROM customers WHERE date_of_birth > CURRENT_DATE)

    UNION ALL
    SELECT 91, 'Plausibility: customer under 18 at account activity window', 'WARN',
           (SELECT count(*) FROM customers
             WHERE date_of_birth > DATE '2007-01-01')
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

WITH checks AS (
    -- Re-run the same checks and roll up to a one-line summary.
    SELECT (SELECT count(*) FROM (SELECT transaction_id FROM transactions GROUP BY transaction_id HAVING count(*)>1) d)
         + (SELECT count(*) FROM (SELECT account_id FROM accounts GROUP BY account_id HAVING count(*)>1) d)
         + (SELECT count(*) FROM (SELECT customer_id FROM customers GROUP BY customer_id HAVING count(*)>1) d)
         + (SELECT count(*) FROM transactions t LEFT JOIN accounts a ON a.account_id=t.sender_account_id WHERE a.account_id IS NULL)
         + (SELECT count(*) FROM transactions WHERE sending_amount <= 0 OR receiving_amount <= 0)
         + (SELECT count(*) FROM accounts WHERE current_balance < 0)
         + (SELECT count(*) FROM transactions WHERE status NOT IN ('COMPLETED','FAILED','PENDING','REVERSED'))
         + (SELECT count(*) FROM transactions WHERE recipient_account_id = sender_account_id)
           AS critical_issue_count
)
SELECT critical_issue_count,
       CASE WHEN critical_issue_count = 0
            THEN 'All critical data-quality checks PASSED.'
            ELSE 'CRITICAL data-quality issues found — investigate FAIL rows above.'
       END AS overall_status
FROM checks;
