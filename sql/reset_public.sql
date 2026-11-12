-- DESTRUCTIVE. Drops every object in the public schema of the connected
-- database (tables, indexes, constraints) and recreates an empty public schema.
--
-- Inspect the current database before running:
--     psql "$DATABASE_URL" -c "\dt"
--     psql "$DATABASE_URL" -c "SELECT count(*) FROM transactions;"
--
-- Implication: all RiskQL tables and rows in this database are deleted.
-- Other databases on the same Postgres server are not affected.
--
--     psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/reset_public.sql

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO CURRENT_USER;
GRANT ALL ON SCHEMA public TO public;
