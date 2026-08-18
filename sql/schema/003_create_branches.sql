CREATE TABLE branches (
    branch_id TEXT PRIMARY KEY,
    branch_name TEXT NOT NULL,
    city TEXT NOT NULL,
    state TEXT,
    country_id TEXT NOT NULL 
        REFERENCES countries(country_id)
);