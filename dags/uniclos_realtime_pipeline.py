"""

DAG principal Uniclos : pipeline temps reel micro-batch (toutes les 2 minutes).



Ingestion (Redpanda) -> Raw -> dbt (staging/dwh) -> DQ -> Monitoring

"""



from __future__ import annotations



import sys

from datetime import datetime, timezone

from pathlib import Path



from airflow import DAG

from airflow.operators.bash import BashOperator

from airflow.operators.empty import EmptyOperator

from airflow.operators.python import BranchPythonOperator, PythonOperator

from airflow.utils.trigger_rule import TriggerRule



PYTHON_ROOT = Path(__file__).resolve().parents[1] / "python"

sys.path.insert(0, str(PYTHON_ROOT))



from consumers.order_event_consumer import consume_to_raw  # noqa: E402

from dq.pipeline_checks import (  # noqa: E402

    log_pipeline_run,

    mark_orders_processed,

    run_dq_checks,

)

from producers.order_event_producer import produce_simulated_events  # noqa: E402



DAG_ID = "uniclos_realtime_pipeline"

DBT_DIM_DATE_SQL = (

    "INSERT INTO dwh.dim_date (date_key, full_date, day_of_week, day_name, week_of_year, "

    "month_num, month_name, quarter_num, year_num) "

    "SELECT TO_CHAR(d, 'YYYYMMDD')::INTEGER, d::DATE, EXTRACT(DOW FROM d)::INTEGER, TO_CHAR(d, 'Day'), "

    "EXTRACT(WEEK FROM d)::INTEGER, EXTRACT(MONTH FROM d)::INTEGER, TO_CHAR(d, 'Month'), "

    "EXTRACT(QUARTER FROM d)::INTEGER, EXTRACT(YEAR FROM d)::INTEGER "

    "FROM generate_series(CURRENT_DATE - 30, CURRENT_DATE + 30, '1 day'::interval) AS d "

    "ON CONFLICT (full_date) DO NOTHING;"

)





def _task_produce(**context):

    started_at = datetime.now(timezone.utc)

    summary = produce_simulated_events()

    summary["started_at"] = started_at.isoformat()

    context["ti"].xcom_push(key="produce_summary", value=summary)

    context["ti"].xcom_push(key="run_started_at", value=started_at.isoformat())

    return summary





def _task_consume(**context):

    summary = consume_to_raw()

    context["ti"].xcom_push(key="consume_summary", value=summary)

    return summary





def _task_dq(**context):

    summary = run_dq_checks()

    processed = mark_orders_processed()

    summary["orders_marked_processed"] = processed

    context["ti"].xcom_push(key="dq_summary", value=summary)

    return summary





def _choose_alert_branch(**context):

    dq = context["ti"].xcom_pull(task_ids="run_dq_checks", key="dq_summary") or {}

    if dq.get("dq_status") == "ALERT":

        return "dq_alert_marker"

    return "dq_ok_marker"





def _log_pipeline_run(**context):

    ti = context["ti"]

    produce = ti.xcom_pull(task_ids="produce_simulated_events", key="produce_summary") or {}

    consume = ti.xcom_pull(task_ids="consume_to_raw", key="consume_summary") or {}

    dq = ti.xcom_pull(task_ids="run_dq_checks", key="dq_summary")



    started_at_raw = ti.xcom_pull(task_ids="produce_simulated_events", key="run_started_at")

    if started_at_raw:

        started_at = datetime.fromisoformat(started_at_raw)

    else:

        started_at = datetime.now(timezone.utc)



    if dq is None:

        dq_status = "ERROR"

        notes = "run_dq_checks indisponible (echec amont ou XCom manquant)"

    elif dq.get("dq_status") == "ALERT":

        dq_status = "ALERT"

        notes = f"Alerte DQ: {dq.get('checks', [])}"

    else:

        dq_status = "OK"

        notes = "Pipeline termine avec succes"



    log_pipeline_run(

        dag_id=DAG_ID,

        task_id="pipeline_run",

        started_at=started_at,

        produced=int(produce.get("events_produced", 0)),

        consumed=int(consume.get("events_consumed", 0)),

        failed=int(consume.get("events_failed", 0)),

        dq_status=dq_status,

        notes=notes,

    )





default_args = {

    "owner": "uniclos",

    "depends_on_past": False,

    "email_on_failure": False,

    "email_on_retry": False,

    "retries": 3,

    "retry_delay": __import__("datetime").timedelta(minutes=1),

}



with DAG(

    dag_id=DAG_ID,

    default_args=default_args,

    description="Pipeline temps reel Uniclos : Redpanda -> PostgreSQL -> dbt -> DQ",

    schedule_interval="*/2 * * * *",

    start_date=datetime(2026, 6, 1, tzinfo=timezone.utc),

    catchup=False,

    tags=["uniclos", "realtime", "etl"],

) as dag:

    produce = PythonOperator(

        task_id="produce_simulated_events",

        python_callable=_task_produce,

    )



    consume = PythonOperator(

        task_id="consume_to_raw",

        python_callable=_task_consume,

    )



    dbt_run = BashOperator(

        task_id="dbt_run",

        bash_command=(
            'psql "$DATABASE_URL" -c '
            f"\"{DBT_DIM_DATE_SQL}\" && "
            "cd /opt/airflow/dbt && "
            "dbt run --profiles-dir . --project-dir . --select staging+"
        ),

    )



    dbt_test = BashOperator(

        task_id="dbt_test",

        bash_command=(

            "cd /opt/airflow/dbt && "

            "dbt test --profiles-dir . --project-dir . --select staging+"

        ),

    )



    dq_checks = PythonOperator(

        task_id="run_dq_checks",

        python_callable=_task_dq,

    )



    branch = BranchPythonOperator(

        task_id="check_dq_status",

        python_callable=_choose_alert_branch,

    )



    dq_ok = EmptyOperator(task_id="dq_ok_marker")

    dq_alert = EmptyOperator(task_id="dq_alert_marker")



    log_run = PythonOperator(

        task_id="log_pipeline_run",

        python_callable=_log_pipeline_run,

        trigger_rule=TriggerRule.ALL_DONE,

    )



    produce >> consume >> dbt_run >> dbt_test >> dq_checks >> branch

    branch >> [dq_ok, dq_alert]

    [dq_ok, dq_alert] >> log_run


