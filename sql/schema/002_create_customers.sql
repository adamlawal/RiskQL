CREATE TABLE customers (
    first_name TEXT NOT NULL,
    middle_name TEXT,
    last_name TEXT NOT NULL,
    date_of_birth DATE NOT NULL,
    email TEXT,
    phone TEXT,
    city TEXT,
    state TEXT,
    country_id TEXT NOT NULL
        REFERENCES countries(country_id),
    -- TIMESTAMPTZ for consistency with the rest of the model (global timestamps).
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    customer_id TEXT PRIMARY KEY
);

