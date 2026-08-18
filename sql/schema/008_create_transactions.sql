CREATE TABLE transactions (
    transaction_id TEXT PRIMARY KEY,

    sender_account_id TEXT NOT NULL
        REFERENCES accounts(account_id),

    recipient_account_id TEXT
        REFERENCES accounts(account_id),

    external_reference TEXT,

    transaction_type_id TEXT NOT NULL
        REFERENCES transaction_types(type_id),

    channel_id TEXT NOT NULL
        REFERENCES channels(channel_id),

    sending_amount NUMERIC(18, 2) NOT NULL,
    sending_currency CHAR(3) NOT NULL,

    receiving_amount NUMERIC(18, 2) NOT NULL,
    receiving_currency CHAR(3) NOT NULL,

    exchange_rate NUMERIC(18, 8),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Origin geography is always explicit (where the transaction originated).
    origin_country_id TEXT NOT NULL
        REFERENCES countries(country_id),

    -- Destination geography is NULL when the recipient is external / unknown.
    -- Geography is NEVER inferred from currency or account country.
    destination_country_id TEXT
        REFERENCES countries(country_id),

    status TEXT NOT NULL,

    CONSTRAINT transactions_status_valid
        CHECK (status IN ('COMPLETED', 'FAILED', 'PENDING', 'REVERSED')),

    CONSTRAINT transactions_sending_amount_positive
        CHECK (sending_amount > 0),

    CONSTRAINT transactions_receiving_amount_positive
        CHECK (receiving_amount > 0),

    CONSTRAINT transactions_exchange_rate_positive
        CHECK (
            exchange_rate IS NULL
            OR exchange_rate > 0
        )
);