-- Channels used for both transactions and login events.
CREATE TABLE channels (
    channel_id   TEXT PRIMARY KEY,
    channel_name TEXT NOT NULL UNIQUE
);
