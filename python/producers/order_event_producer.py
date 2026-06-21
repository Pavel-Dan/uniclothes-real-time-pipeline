"""Simulateur d evenements commandes web/POS vers Redpanda (API Kafka)."""

from __future__ import annotations

import json
import logging
import random
import uuid
from datetime import datetime, timezone

from kafka import KafkaProducer

from config import (
    EVENTS_PER_RUN,
    KAFKA_BOOTSTRAP_SERVERS,
    PRICE_BY_REF,
    PRODUCT_REFS,
    SAMPLE_CUSTOMERS,
    STORE_CODES,
    TOPIC_ORDERS_POS,
    TOPIC_ORDERS_WEB,
)

logger = logging.getLogger(__name__)


def build_web_order(run_id: str, index: int) -> dict:
    """Construit un payload commande e-commerce ou app mobile."""
    product_ref = random.choice(PRODUCT_REFS)
    quantity = random.randint(1, 3)
    unit_price = PRICE_BY_REF.get(product_ref, 49.90)
    channel = random.choice(["web", "app"])
    return {
        "order_id": f"WEB-RT-{run_id}-{index:04d}",
        "customer_email": random.choice(SAMPLE_CUSTOMERS),
        "channel": channel,
        "store_code": None,
        "product_ref": product_ref,
        "quantity": quantity,
        "unit_price_eur": unit_price,
        "amount_eur": round(quantity * unit_price, 2),
        "order_timestamp": datetime.now(timezone.utc).isoformat(),
    }


def build_pos_order(run_id: str, index: int) -> dict:
    """Construit un payload vente caisse boutique."""
    product_ref = random.choice(PRODUCT_REFS)
    quantity = random.randint(1, 2)
    unit_price = PRICE_BY_REF.get(product_ref, 49.90)
    return {
        "order_id": f"POS-RT-{run_id}-{index:04d}",
        "customer_email": random.choice(SAMPLE_CUSTOMERS),
        "channel": "store",
        "store_code": random.choice(STORE_CODES),
        "product_ref": product_ref,
        "quantity": quantity,
        "unit_price_eur": unit_price,
        "amount_eur": round(quantity * unit_price, 2),
        "order_timestamp": datetime.now(timezone.utc).isoformat(),
    }


def produce_simulated_events(count: int | None = None) -> dict:
    """
    Publie des evenements simules sur les topics web et POS.
    Retourne un resume pour monitoring Airflow.
    """
    total = count or EVENTS_PER_RUN
    run_id = uuid.uuid4().hex[:8]
    web_count = total // 2
    pos_count = total - web_count

    producer = KafkaProducer(
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        acks="all",
        retries=3,
    )

    produced_web = 0
    produced_pos = 0

    try:
        for i in range(web_count):
            payload = build_web_order(run_id, i)
            producer.send(TOPIC_ORDERS_WEB, payload)
            produced_web += 1

        for i in range(pos_count):
            payload = build_pos_order(run_id, i)
            producer.send(TOPIC_ORDERS_POS, payload)
            produced_pos += 1

        producer.flush()
    finally:
        producer.close()

    summary = {
        "run_id": run_id,
        "events_produced": produced_web + produced_pos,
        "events_web": produced_web,
        "events_pos": produced_pos,
    }
    logger.info("Produced events: %s", summary)
    return summary


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print(produce_simulated_events())
