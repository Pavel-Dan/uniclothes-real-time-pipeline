"""Fixtures pytest — ajoute python/ au PYTHONPATH."""

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PYTHON_DIR = ROOT / "python"
DAGS_DIR = ROOT / "dags"

for path in (PYTHON_DIR, DAGS_DIR):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

os.environ.setdefault(
    "DATABASE_URL",
    "postgresql://test_user:test_pass@localhost:5433/test_db",
)
