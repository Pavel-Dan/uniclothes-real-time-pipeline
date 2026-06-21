-- Uniclos Bloc3: pipeline observability metrics

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE TABLE IF NOT EXISTS monitoring.pipeline_runs (
    run_id          BIGSERIAL PRIMARY KEY,
    dag_id          VARCHAR(100),
    task_id         VARCHAR(100),
    started_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    finished_at     TIMESTAMP,
    events_produced INTEGER DEFAULT 0,
    events_consumed INTEGER DEFAULT 0,
    events_failed   INTEGER DEFAULT 0,
    dq_status       VARCHAR(20),
    duration_sec    NUMERIC(10,2),
    notes           TEXT
);

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_started
    ON monitoring.pipeline_runs (started_at DESC);

COMMENT ON SCHEMA monitoring IS 'Metriques d execution du pipeline temps reel Uniclos';
