-- =============================================================================
-- 009_create_indexes.sql
-- Secondary indexes for analytical query performance.
--
-- Primary keys and UNIQUE constraints are already indexed automatically by
-- PostgreSQL. Foreign-key columns are NOT indexed automatically, so we add
-- indexes on the join/filter columns that the analysis scripts use most.
--
-- These indexes are optional for correctness but make the analytical queries
-- (grouping/filtering by channel, type, country, status, time) noticeably
-- faster on larger datasets.
-- =============================================================================

-- Accounts: joined from transactions and grouped by customer/branch.
CREATE INDEX IF NOT EXISTS idx_accounts_customer_id ON accounts (customer_id);
CREATE INDEX IF NOT EXISTS idx_accounts_branch_id   ON accounts (branch_id);
CREATE INDEX IF NOT EXISTS idx_accounts_status      ON accounts (status);

-- Transactions: the central analytical table.
CREATE INDEX IF NOT EXISTS idx_txn_sender_account      ON transactions (sender_account_id);
CREATE INDEX IF NOT EXISTS idx_txn_recipient_account   ON transactions (recipient_account_id);
CREATE INDEX IF NOT EXISTS idx_txn_type                ON transactions (transaction_type_id);
CREATE INDEX IF NOT EXISTS idx_txn_channel             ON transactions (channel_id);
CREATE INDEX IF NOT EXISTS idx_txn_status              ON transactions (status);
CREATE INDEX IF NOT EXISTS idx_txn_created_at          ON transactions (created_at);
CREATE INDEX IF NOT EXISTS idx_txn_origin_country      ON transactions (origin_country_id);
CREATE INDEX IF NOT EXISTS idx_txn_destination_country ON transactions (destination_country_id);
-- Composite for the common "corridor" grouping (origin -> destination).
CREATE INDEX IF NOT EXISTS idx_txn_corridor            ON transactions (origin_country_id, destination_country_id);

-- Login events.
CREATE INDEX IF NOT EXISTS idx_login_customer      ON login_events (customer_id);
CREATE INDEX IF NOT EXISTS idx_login_channel       ON login_events (channel_id);
CREATE INDEX IF NOT EXISTS idx_login_status        ON login_events (status);
CREATE INDEX IF NOT EXISTS idx_login_time          ON login_events ("timestamp");
CREATE INDEX IF NOT EXISTS idx_login_origin_country ON login_events (origin_country_id);

-- Customers: grouped by recorded country for geo-mismatch analysis.
CREATE INDEX IF NOT EXISTS idx_customers_country ON customers (country_id);
