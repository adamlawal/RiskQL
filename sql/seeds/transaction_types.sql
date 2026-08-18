-- =============================================================================
-- Seed: transaction_types (reference data)
-- The set of transaction categories used across the model. type_name is UNIQUE.
-- =============================================================================
INSERT INTO transaction_types (type_id, type_name) VALUES
    ('TT01', 'TRANSFER'),
    ('TT02', 'DEPOSIT'),
    ('TT03', 'WITHDRAWAL'),
    ('TT04', 'BILL_PAYMENT'),
    ('TT05', 'CARD_PAYMENT'),
    ('TT06', 'INTERNATIONAL_REMITTANCE');
