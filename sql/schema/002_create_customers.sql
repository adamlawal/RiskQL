-- Banking customers. country_id is the *recorded* customer country (KYC /
-- onboarding location). It is compared with login origin later; it is NOT
-- inferred from account currency or transaction geography.
CREATE TABLE customers (
    customer_id   TEXT PRIMARY KEY,
    first_name    TEXT NOT NULL,
    middle_name   TEXT,
    last_name     TEXT NOT NULL,
    date_of_birth DATE NOT NULL,
    email         TEXT,
    phone         TEXT,
    city          TEXT,
    state         TEXT,
    country_id    TEXT NOT NULL REFERENCES countries (country_id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT customers_dob_not_future
        CHECK (date_of_birth <= CURRENT_DATE)
);
