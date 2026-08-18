CREATE TABLE login_events (
    login_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL 
        REFERENCES customers(customer_id),
    channel_id TEXT NOT NULL
        REFERENCES channels(channel_id),
    -- NOTE: "timestamp" is a reserved-ish word in SQL. It is legal as a column
    -- name in PostgreSQL and is kept here to match the original ERD. When it
    -- appears ambiguously it is qualified (e.g. login_events.timestamp).
    timestamp TIMESTAMPTZ NOT NULL,
    ip_address TEXT,
    -- Nullable: the login origin country may be unknown (e.g. missing geo-IP).
    origin_country_id TEXT
        REFERENCES countries(country_id),
    status TEXT NOT NULL,

    CONSTRAINT login_events_status_valid
        CHECK (status IN ('SUCCESS', 'FAILED'))
);