#!/bin/bash
# Applique les mots de passe des roles depuis les variables d environnement Docker
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
ALTER ROLE uniclothes_analyst WITH PASSWORD '${ANALYST_DB_PASSWORD}';
ALTER ROLE uniclothes_dpo WITH PASSWORD '${DPO_DB_PASSWORD}';
ALTER ROLE uniclos_grafana WITH PASSWORD '${GRAFANA_DB_PASSWORD}';
EOSQL
