CREATE TABLE accounts (
    account_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL 
        REFERENCES customers(customer_id),
    branch_id TEXT NOT NULL 
        REFERENCES branches(branch_id),
    account_type TEXT NOT NULL,
    currency_code CHAR(3) NOT NULL,
    current_balance NUMERIC(18, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- creation_channel is intentionally free TEXT (not a FK to channels):
    -- it records how the account was opened and may include values that are
    -- not transactional channels. Kept nullable because it may be unknown.
    creation_channel TEXT,
    status TEXT NOT NULL,

    CONSTRAINT accounts_balance_nonnegative
        CHECK (current_balance >= 0),

    -- Constrain to a defined business domain for data quality.
    CONSTRAINT accounts_account_type_valid
        CHECK (account_type IN ('CURRENT', 'SAVINGS', 'CHECKING')),

    CONSTRAINT accounts_status_valid
        CHECK (status IN ('ACTIVE', 'DORMANT', 'SUSPENDED', 'CLOSED'))
);