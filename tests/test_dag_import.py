"""Tests d import et structure du DAG Airflow."""

import importlib.util
from pathlib import Path


def test_dag_file_exists():
    dag_path = Path(__file__).resolve().parents[1] / "dags" / "uniclos_realtime_pipeline.py"
    assert dag_path.exists()


def test_dag_module_loads_without_airflow_runtime():
    """Verifie que le fichier DAG est syntaxiquement valide."""
    dag_path = Path(__file__).resolve().parents[1] / "dags" / "uniclos_realtime_pipeline.py"
    source = dag_path.read_text(encoding="utf-8")
    compile(source, str(dag_path), "exec")


def test_dag_id_present_in_source():
    dag_path = Path(__file__).resolve().parents[1] / "dags" / "uniclos_realtime_pipeline.py"
    source = dag_path.read_text(encoding="utf-8")
    assert 'DAG_ID = "uniclos_realtime_pipeline"' in source
    assert "produce_simulated_events" in source
    assert "dbt_test" in source
    assert "run_dq_checks" in source
