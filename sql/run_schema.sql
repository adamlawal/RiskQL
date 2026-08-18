-- =============================================================================
-- run_schema.sql
-- Master script: creates all tables and indexes in dependency order, then loads
-- the reference/seed data (countries, transaction_types, channels, branches).
--
-- Run from the repository root with psql, e.g.:
--     psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/run_schema.sql
--
-- This script does NOT load the bulk synthetic data (customers, accounts,
-- login_events, transactions). Generate and load that separately:
--     python src/generate_data.py
--     psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/load_data.sql
-- =============================================================================

\echo '>> Creating schema...'

-- Tables in dependency order.
\i sql/schema/001_create_countries.sql
\i sql/schema/002_create_customers.sql
\i sql/schema/003_create_branches.sql
\i sql/schema/004_create_transaction_types.sql
\i sql/schema/005_create_channels.sql
\i sql/schema/006_create_accounts.sql
\i sql/schema/007_create_login_events.sql
\i sql/schema/008_create_transactions.sql

-- Secondary indexes (after tables exist).
\i sql/schema/009_create_indexes.sql

\echo '>> Loading reference/seed data...'

\i sql/seeds/countries.sql
\i sql/seeds/transaction_types.sql
\i sql/seeds/channels.sql
\i sql/seeds/branches.sql

\echo '>> Schema + reference data ready.'
