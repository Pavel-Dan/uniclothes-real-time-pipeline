# DDL PostgreSQL — source unique montee dans docker-compose (sql/init -> postgres initdb)

Fichiers executes automatiquement au premier demarrage de PostgreSQL, dans l'ordre :

| Fichier | Role |
|---------|------|
| 00_create_airflow_db.sql | Base metadata Airflow |
| 01_create_schemas.sql | Schemas raw/staging/dwh/audit |
| 02-04 | Tables raw, staging, dwh |
| 05_create_streaming_tables.sql | Tables temps reel |
| 06_create_monitoring_tables.sql | monitoring.pipeline_runs |
| 07_load_reference_data.sql | Charge CSV seeds + dimensions |
| 08_rgpd_security.sql | Roles et fonctions RGPD |
| 09_grafana_readonly.sql | Role lecture Grafana |

**Ne pas dupliquer** dans docker/postgres/init — docker-compose monte directement ce dossier.
