-- Customer authentication attempts. origin_country_id is IP-derived geography
-- and is approximate; it is an indicator, not proof of physical location.
-- Column name "timestamp" is quoted because it is a reserved-ish SQL word;
-- it is kept to match the project ERD.
CREATE TABLE login_events (
    login_id          TEXT PRIMARY KEY,
    customer_id       TEXT NOT NULL REFERENCES customers (customer_id),
    channel_id        TEXT NOT NULL REFERENCES channels (channel_id),
    "timestamp"       TIMESTAMPTZ NOT NULL,
    ip_address        TEXT,
    origin_country_id TEXT REFERENCES countries (country_id),
    status            TEXT NOT NULL,

    CONSTRAINT login_events_status_valid
        CHECK (status IN ('SUCCESS', 'FAILED'))
);
