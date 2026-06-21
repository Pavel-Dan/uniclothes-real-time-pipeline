"""Configuration centralisee du pipeline temps reel Uniclos."""

import os

KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:19092")
TOPIC_ORDERS_WEB = os.getenv("TOPIC_ORDERS_WEB", "uniclos.orders.web")
TOPIC_ORDERS_POS = os.getenv("TOPIC_ORDERS_POS", "uniclos.orders.pos")
TOPIC_ORDERS_DLQ = os.getenv("TOPIC_ORDERS_DLQ", "uniclos.orders.dlq")

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL must be set (see docker/.env)")

EVENTS_PER_RUN = int(os.getenv("EVENTS_PER_RUN", "8"))
CONSUMER_TIMEOUT_MS = int(os.getenv("CONSUMER_TIMEOUT_MS", "5000"))
CONSUMER_MAX_MESSAGES = int(os.getenv("CONSUMER_MAX_MESSAGES", "50"))

PRODUCT_REFS = [
    "UC-TS-001", "UC-TS-002", "UC-PA-001", "UC-PA-002", "UC-RO-001",
    "UC-RO-002", "UC-VE-001", "UC-VE-002", "UC-AC-001", "UC-AC-002",
    "UC-CH-001", "UC-CH-002", "UC-TS-003", "UC-PA-003", "UC-RO-003",
]

STORE_CODES = [
    "PAR01", "PAR02", "LYO01", "MAR01", "BOR01",
    "LIL01", "NAN01", "STR01", "TLS01", "NCE01",
]

SAMPLE_CUSTOMERS = [
    "anais.thomas0@email.com",
    "hugo.roux1@email.com",
    "gabriel.bertrand2@email.com",
    "louis.michel4@email.com",
    "lucas.garcia6@email.com",
    "anais.fournier7@email.com",
    "manon.lefebvre11@email.com",
    "maxime.simon12@email.com",
]

PRICE_BY_REF = {
    "UC-TS-001": 29.90, "UC-TS-002": 34.90, "UC-PA-001": 79.90,
    "UC-PA-002": 59.90, "UC-RO-001": 89.90, "UC-RO-002": 69.90,
    "UC-VE-001": 99.90, "UC-VE-002": 119.90, "UC-AC-001": 39.90,
    "UC-AC-002": 49.90, "UC-CH-001": 89.90, "UC-CH-002": 109.90,
    "UC-TS-003": 24.90, "UC-PA-003": 44.90, "UC-RO-003": 74.90,
}
