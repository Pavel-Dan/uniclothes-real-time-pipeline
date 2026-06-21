-- UNICLOTHES: Create schemas and extensions
-- Layered architecture: raw -> staging -> dwh

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS dwh;
CREATE SCHEMA IF NOT EXISTS audit;

COMMENT ON SCHEMA raw IS 'Landing zone - données brutes des sources simulées';
COMMENT ON SCHEMA staging IS 'Zone de nettoyage, déduplication et golden record';
COMMENT ON SCHEMA dwh IS 'Entrepôt analytique - star schema';
COMMENT ON SCHEMA audit IS 'Journalisation RGPD et accès';
