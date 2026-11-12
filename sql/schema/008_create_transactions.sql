-- Central analytical entity. Origin and destination geography are stored
-- explicitly and are NEVER inferred from currency or from the account's
-- branch country.
--
-- External recipients: recipient_account_id is NULL and external_reference
-- is populated. Internal transfers: recipient_account_id is set and
-- external_reference is NULL.
CREATE TABLE transactions (
    transaction_id         TEXT PRIMARY KEY,

    sender_account_id      TEXT NOT NULL REFERENCES accounts (account_id),
    recipient_account_id   TEXT REFERENCES accounts (account_id),
    external_reference     TEXT,

    transaction_type_id    TEXT NOT NULL REFERENCES transaction_types (type_id),
    channel_id             TEXT NOT NULL REFERENCES channels (channel_id),

    sending_amount         NUMERIC(18, 2) NOT NULL,
    sending_currency       CHAR(3) NOT NULL,
    receiving_amount       NUMERIC(18, 2) NOT NULL,
    receiving_currency     CHAR(3) NOT NULL,
    exchange_rate          NUMERIC(18, 8),

    created_at             TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    origin_country_id      TEXT NOT NULL REFERENCES countries (country_id),
    destination_country_id TEXT REFERENCES countries (country_id),

    status                 TEXT NOT NULL,

    CONSTRAINT transactions_status_valid
        CHECK (status IN ('COMPLETED', 'FAILED', 'PENDING', 'REVERSED')),

    CONSTRAINT transactions_sending_amount_positive
        CHECK (sending_amount > 0),

    CONSTRAINT transactions_receiving_amount_positive
        CHECK (receiving_amount > 0),

    CONSTRAINT transactions_exchange_rate_positive
        CHECK (exchange_rate IS NULL OR exchange_rate > 0),

    CONSTRAINT transactions_sending_currency_iso3
        CHECK (sending_currency ~ '^[A-Z]{3}$'),

    CONSTRAINT transactions_receiving_currency_iso3
        CHECK (receiving_currency ~ '^[A-Z]{3}$'),

    CONSTRAINT transactions_recipient_or_external
        CHECK (
            (recipient_account_id IS NOT NULL AND external_reference IS NULL)
            OR (recipient_account_id IS NULL AND external_reference IS NOT NULL)
        ),

    CONSTRAINT transactions_no_self_transfer
        CHECK (
            recipient_account_id IS NULL
            OR recipient_account_id <> sender_account_id
        )
);
