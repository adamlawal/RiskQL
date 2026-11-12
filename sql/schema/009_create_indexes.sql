-- Secondary indexes for analytical query performance.
-- PKs and UNIQUE constraints already have indexes. Foreign-key columns do
-- not, so we index the join/filter columns used by the analysis scripts.

CREATE INDEX IF NOT EXISTS idx_accounts_customer_id ON accounts (customer_id);
CREATE INDEX IF NOT EXISTS idx_accounts_branch_id   ON accounts (branch_id);
CREATE INDEX IF NOT EXISTS idx_accounts_status      ON accounts (status);

CREATE INDEX IF NOT EXISTS idx_txn_sender_account      ON transactions (sender_account_id);
CREATE INDEX IF NOT EXISTS idx_txn_recipient_account   ON transactions (recipient_account_id);
CREATE INDEX IF NOT EXISTS idx_txn_type                ON transactions (transaction_type_id);
CREATE INDEX IF NOT EXISTS idx_txn_channel             ON transactions (channel_id);
CREATE INDEX IF NOT EXISTS idx_txn_status              ON transactions (status);
CREATE INDEX IF NOT EXISTS idx_txn_created_at          ON transactions (created_at);
CREATE INDEX IF NOT EXISTS idx_txn_origin_country      ON transactions (origin_country_id);
CREATE INDEX IF NOT EXISTS idx_txn_destination_country ON transactions (destination_country_id);
CREATE INDEX IF NOT EXISTS idx_txn_corridor            ON transactions (origin_country_id, destination_country_id);

CREATE INDEX IF NOT EXISTS idx_login_customer       ON login_events (customer_id);
CREATE INDEX IF NOT EXISTS idx_login_channel        ON login_events (channel_id);
CREATE INDEX IF NOT EXISTS idx_login_status         ON login_events (status);
CREATE INDEX IF NOT EXISTS idx_login_time           ON login_events ("timestamp");
CREATE INDEX IF NOT EXISTS idx_login_origin_country ON login_events (origin_country_id);

CREATE INDEX IF NOT EXISTS idx_customers_country ON customers (country_id);
