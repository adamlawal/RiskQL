-- Master script: create all tables and indexes in dependency order, then load
-- reference/seed data (countries, transaction_types, channels, branches).
--
-- Run from the repository root:
--     psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/run_schema.sql
--
-- This script does NOT load bulk synthetic data. Generate and load that with:
--     python src/generate_data.py
--     psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/load_data.sql
--
-- It also does NOT drop existing objects. To rebuild from a clean schema, run
-- sql/reset_public.sql first (destructive; see that file).

\echo '>> Creating schema...'

\i sql/schema/001_create_countries.sql
\i sql/schema/002_create_customers.sql
\i sql/schema/003_create_branches.sql
\i sql/schema/004_create_transaction_types.sql
\i sql/schema/005_create_channels.sql
\i sql/schema/006_create_accounts.sql
\i sql/schema/007_create_login_events.sql
\i sql/schema/008_create_transactions.sql
\i sql/schema/009_create_indexes.sql

\echo '>> Loading reference/seed data...'

\i sql/seeds/countries.sql
\i sql/seeds/transaction_types.sql
\i sql/seeds/channels.sql
\i sql/seeds/branches.sql

\echo '>> Schema + reference data ready.'
