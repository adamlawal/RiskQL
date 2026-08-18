-- =============================================================================
-- Seed: channels (reference data)
-- Banking channels through which transactions and logins occur.
-- channel_name is UNIQUE.
-- =============================================================================
INSERT INTO channels (channel_id, channel_name) VALUES
    ('CH01', 'MOBILE_APP'),
    ('CH02', 'INTERNET_BANKING'),
    ('CH03', 'ATM'),
    ('CH04', 'BRANCH'),
    ('CH05', 'POS'),
    ('CH06', 'PHONE_BANKING');
