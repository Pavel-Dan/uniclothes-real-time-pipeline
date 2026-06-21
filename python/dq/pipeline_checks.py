"""Controles qualite post-chargement et ecriture monitoring.pipeline_runs."""

from __future__ import annotations

import logging
from datetime import datetime, timezone

import psycopg2

from config import DATABASE_URL

logger = logging.getLogger(__name__)

PIPELINE_DQ_CHECKS = [
    {
        "metric_name": "streaming_null_order_rate_pct",
        "sql": """
            SELECT ROUND(
                100.0 * COUNT(*) FILTER (WHERE order_id IS NULL OR amount_eur IS NULL)
                / NULLIF(COUNT(*), 0), 2
            )
            FROM raw.streaming_orders
            WHERE consumed_at >= NOW() - INTERVAL '1 day'
        """,
        "target_value": 0.0,
        "comparator": "lte",
    },
    {
        "metric_name": "streaming_duplicate_order_rate_pct",
        "sql": """
            SELECT ROUND(
                100.0 * (COUNT(*) - COUNT(DISTINCT order_id))
                / NULLIF(COUNT(*), 0), 2
            )
            FROM raw.streaming_orders
        """,
        "target_value": 0.0,
        "comparator": "lte",
    },
    {
        "metric_name": "fact_sales_orphan_product_rate_pct",
        "sql": """
            SELECT ROUND(
                100.0 * COUNT(*) FILTER (WHERE dp.product_key IS NULL)
                / NULLIF(COUNT(*), 0), 2
            )
            FROM dwh.fact_sales fs
            LEFT JOIN dwh.dim_product dp ON fs.product_key = dp.product_key
        """,
        "target_value": 0.0,
        "comparator": "lte",
    },
    {
        "metric_name": "failed_events_count_24h",
        "sql": """
            SELECT COUNT(*)::NUMERIC
            FROM raw.failed_events
            WHERE failed_at >= NOW() - INTERVAL '1 day'
        """,
        "target_value": 5.0,
        "comparator": "lte",
    },
]


def _evaluate_status(value: float | None, target: float, comparator: str) -> str:
    if value is None:
        return "ALERT"
    if comparator == "lte":
        return "OK" if value <= target else "ALERT"
    if comparator == "gte":
        return "OK" if value >= target else "ALERT"
    return "INFO"


def run_dq_checks() -> dict:
    """
    Execute les controles qualite et met a jour staging.quality_metrics.
    Retourne un resume avec statut global.
    """
    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = True
    results = []
    global_status = "OK"

    try:
        with conn.cursor() as cur:
            for check in PIPELINE_DQ_CHECKS:
                cur.execute(check["sql"])
                row = cur.fetchone()
                value = float(row[0]) if row and row[0] is not None else None
                status = _evaluate_status(value, check["target_value"], check["comparator"])
                if status == "ALERT":
                    global_status = "ALERT"

                cur.execute(
                    """
                    INSERT INTO staging.quality_metrics
                        (metric_name, metric_value, target_value, status)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (check["metric_name"], value, check["target_value"], status),
                )
                results.append(
                    {
                        "metric_name": check["metric_name"],
                        "metric_value": value,
                        "target_value": check["target_value"],
                        "status": status,
                    }
                )
    finally:
        conn.close()

    summary = {"dq_status": global_status, "checks": results}
    logger.info("DQ summary: %s", summary)
    return summary


def mark_orders_processed() -> int:
    """Marque les commandes brutes comme traitees apres dbt."""
    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE raw.streaming_orders
                SET processed = TRUE
                WHERE processed = FALSE
                  AND order_id IN (SELECT DISTINCT order_id FROM dwh.fact_sales)
                """
            )
            return cur.rowcount
    finally:
        conn.close()


def log_pipeline_run(
    dag_id: str,
    task_id: str,
    started_at: datetime,
    produced: int = 0,
    consumed: int = 0,
    failed: int = 0,
    dq_status: str = "OK",
    notes: str | None = None,
) -> None:
    """Enregistre une execution pipeline dans monitoring.pipeline_runs."""
    finished_at = datetime.now(timezone.utc)
    duration = (finished_at - started_at).total_seconds()

    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO monitoring.pipeline_runs (
                    dag_id, task_id, started_at, finished_at,
                    events_produced, events_consumed, events_failed,
                    dq_status, duration_sec, notes
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    dag_id, task_id, started_at, finished_at,
                    produced, consumed, failed, dq_status, duration, notes,
                ),
            )
    finally:
        conn.close()
