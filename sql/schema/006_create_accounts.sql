-- Customer accounts. A customer may hold several accounts, including in
-- different currencies. currency_code is independent of branch country.
-- geography is NEVER inferred from currency.
CREATE TABLE accounts (
    account_id       TEXT PRIMARY KEY,
    customer_id      TEXT NOT NULL REFERENCES customers (customer_id),
    branch_id        TEXT NOT NULL REFERENCES branches (branch_id),
    account_type     TEXT NOT NULL,
    currency_code    CHAR(3) NOT NULL,
    current_balance  NUMERIC(18, 2) NOT NULL DEFAULT 0.00,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- How the account was opened. Free TEXT (not a FK to channels) because
    -- onboarding channels can include values that are not transactional.
    creation_channel TEXT,
    status           TEXT NOT NULL,

    CONSTRAINT accounts_balance_nonnegative
        CHECK (current_balance >= 0),

    CONSTRAINT accounts_account_type_valid
        CHECK (account_type IN ('CURRENT', 'SAVINGS', 'CHECKING')),

    CONSTRAINT accounts_status_valid
        CHECK (status IN ('ACTIVE', 'DORMANT', 'SUSPENDED', 'CLOSED')),

    CONSTRAINT accounts_currency_iso3
        CHECK (currency_code ~ '^[A-Z]{3}$')
);
