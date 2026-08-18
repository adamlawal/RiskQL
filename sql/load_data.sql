-- =============================================================================
-- load_data.sql
-- Loads the generated synthetic bulk data (CSV) into the tables.
--
-- Prerequisites:
--   1. Schema + reference data already loaded (sql/run_schema.sql).
--   2. CSVs generated:  python src/generate_data.py
--
-- Run from the repository root so the relative CSV paths resolve:
--     psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/load_data.sql
--
-- Uses \copy (client-side) so it works over a normal client connection and does
-- not require the server to have filesystem access to the CSVs.
-- Empty fields in the CSV are loaded as SQL NULL (NULL '').
-- Column lists match the CSV header order exactly.
-- =============================================================================

\echo '>> Loading customers...'
\copy customers (customer_id, first_name, middle_name, last_name, date_of_birth, email, phone, city, state, country_id, created_at) FROM 'data/processed/customers.csv' WITH (FORMAT csv, HEADER true, NULL '')

\echo '>> Loading accounts...'
\copy accounts (account_id, customer_id, branch_id, account_type, currency_code, current_balance, created_at, creation_channel, status) FROM 'data/processed/accounts.csv' WITH (FORMAT csv, HEADER true, NULL '')

\echo '>> Loading login_events...'
\copy login_events (login_id, customer_id, channel_id, "timestamp", ip_address, origin_country_id, status) FROM 'data/processed/login_events.csv' WITH (FORMAT csv, HEADER true, NULL '')

\echo '>> Loading transactions...'
\copy transactions (transaction_id, sender_account_id, recipient_account_id, external_reference, transaction_type_id, channel_id, sending_amount, sending_currency, receiving_amount, receiving_currency, exchange_rate, created_at, origin_country_id, destination_country_id, status) FROM 'data/processed/transactions.csv' WITH (FORMAT csv, HEADER true, NULL '')

\echo '>> Bulk data loaded. Row counts:'
SELECT 'customers'     AS table, count(*) FROM customers
UNION ALL SELECT 'accounts',      count(*) FROM accounts
UNION ALL SELECT 'login_events',  count(*) FROM login_events
UNION ALL SELECT 'transactions',  count(*) FROM transactions
ORDER BY 1;
