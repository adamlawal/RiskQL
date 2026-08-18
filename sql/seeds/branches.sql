-- =============================================================================
-- Seed: branches (reference data)
-- A fixed set of bank branches. Each branch belongs to a country. Branches are
-- treated as reference data (a known, slowly-changing list) rather than
-- generated data. country_id values must exist in the countries seed.
-- =============================================================================
INSERT INTO branches (branch_id, branch_name, city, state, country_id) VALUES
    ('B001', 'Lagos Marina Branch',     'Lagos',        'Lagos',            'C001'),
    ('B002', 'Abuja Central Branch',     'Abuja',        'FCT',              'C001'),
    ('B003', 'Port Harcourt Branch',     'Port Harcourt','Rivers',          'C001'),
    ('B004', 'Accra Main Branch',        'Accra',        'Greater Accra',    'C002'),
    ('B005', 'New York Midtown Branch',  'New York',     'New York',         'C003'),
    ('B006', 'London City Branch',       'London',       'England',          'C004'),
    ('B007', 'Nairobi CBD Branch',       'Nairobi',      'Nairobi County',   'C005'),
    ('B008', 'Johannesburg Sandton',     'Johannesburg', 'Gauteng',          'C006'),
    ('B009', 'Toronto Downtown Branch',  'Toronto',      'Ontario',          'C007'),
    ('B010', 'Frankfurt Main Branch',    'Frankfurt',    'Hesse',            'C008'),
    ('B011', 'Dubai DIFC Branch',        'Dubai',        'Dubai',            'C010'),
    ('B012', 'Mumbai Fort Branch',       'Mumbai',       'Maharashtra',      'C011');
