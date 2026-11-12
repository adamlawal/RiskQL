-- Physical bank branches. Treated as slowly-changing reference data.
-- A branch belongs to exactly one country; customers may hold accounts at
-- branches outside their recorded country (explicit, not inferred).
CREATE TABLE branches (
    branch_id   TEXT PRIMARY KEY,
    branch_name TEXT NOT NULL,
    city        TEXT NOT NULL,
    state       TEXT,
    country_id  TEXT NOT NULL REFERENCES countries (country_id)
);
