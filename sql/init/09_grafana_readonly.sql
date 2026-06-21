-- Read-only Grafana role (mot de passe via sql/init/10_role_passwords.sh)

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'uniclos_grafana') THEN
        CREATE ROLE uniclos_grafana LOGIN;
    END IF;
END
$$;

GRANT USAGE ON SCHEMA monitoring TO uniclos_grafana;
GRANT USAGE ON SCHEMA staging TO uniclos_grafana;
GRANT USAGE ON SCHEMA raw TO uniclos_grafana;
GRANT SELECT ON monitoring.pipeline_runs TO uniclos_grafana;
GRANT SELECT ON staging.quality_metrics TO uniclos_grafana;
GRANT SELECT ON raw.streaming_orders TO uniclos_grafana;
GRANT SELECT ON raw.failed_events TO uniclos_grafana;
