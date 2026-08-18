-- =============================================================================
-- Seed: countries (reference data)
-- ISO 3166-1 alpha-2 codes. Region is a coarse analytical grouping, not an
-- official standard. Country IDs C001-C005 are preserved from the original seed.
-- =============================================================================
INSERT INTO countries (country_id, country_name, country_code, region) VALUES
    ('C001', 'Nigeria',              'NG', 'West Africa'),
    ('C002', 'Ghana',                'GH', 'West Africa'),
    ('C003', 'United States',        'US', 'North America'),
    ('C004', 'United Kingdom',       'GB', 'Europe'),
    ('C005', 'Kenya',                'KE', 'East Africa'),
    ('C006', 'South Africa',         'ZA', 'Southern Africa'),
    ('C007', 'Canada',               'CA', 'North America'),
    ('C008', 'Germany',              'DE', 'Europe'),
    ('C009', 'France',               'FR', 'Europe'),
    ('C010', 'United Arab Emirates', 'AE', 'Middle East'),
    ('C011', 'India',                'IN', 'South Asia'),
    ('C012', 'China',                'CN', 'East Asia'),
    ('C013', 'Egypt',                'EG', 'North Africa'),
    ('C014', 'Brazil',               'BR', 'South America'),
    ('C015', 'Australia',            'AU', 'Oceania');
