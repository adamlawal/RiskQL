-- Geographic reference table. country_code is ISO 3166-1 alpha-2 and is the
-- stable natural identifier; country_id is a project surrogate used as the PK
-- so FKs stay short and readable (C001, C002, ...).
CREATE TABLE countries (
    country_id   TEXT PRIMARY KEY,
    country_name TEXT NOT NULL,
    country_code CHAR(2) NOT NULL UNIQUE,
    region       TEXT,

    CONSTRAINT countries_code_iso2
        CHECK (country_code ~ '^[A-Z]{2}$')
);
