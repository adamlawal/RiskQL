CREATE TABLE countries (
    country_id   TEXT PRIMARY KEY,
    country_name TEXT NOT NULL,
    -- ISO 3166-1 alpha-2 code (e.g. NG, US). Unique reference code.
    country_code CHAR(2) NOT NULL UNIQUE,
    region       TEXT
);
