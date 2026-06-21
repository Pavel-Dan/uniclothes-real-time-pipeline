"""Consommateur Kafka -> PostgreSQL raw.streaming_orders + DLQ."""

from __future__ import annotations

import json
import logging
from typing import Any

import psycopg2
from kafka import KafkaConsumer, KafkaProducer
from psycopg2.extras import Json

from config import (
    CONSUMER_MAX_MESSAGES,
    CONSUMER_TIMEOUT_MS,
    DATABASE_URL,
    KAFKA_BOOTSTRAP_SERVERS,
    TOPIC_ORDERS_DLQ,
    TOPIC_ORDERS_POS,
    TOPIC_ORDERS_WEB,
)
from dq.validators import validate_order_event

logger = logging.getLogger(__name__)

TOPICS = [TOPIC_ORDERS_WEB, TOPIC_ORDERS_POS]


def _parse_timestamp(value: str):
    """Parse ISO timestamp from event payload."""
    from datetime import datetime

    if value.endswith("Z"):
        value = value.replace("Z", "+00:00")
    return datetime.fromisoformat(value)


def consume_to_raw() -> dict:
    """
    Lit un batch de messages Kafka, valide et insere dans raw.streaming_orders.
    Messages invalides -> raw.failed_events + topic DLQ.
    """
    consumer = KafkaConsumer(
        *TOPICS,
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        auto_offset_reset="latest",
        enable_auto_commit=True,
        consumer_timeout_ms=CONSUMER_TIMEOUT_MS,
        group_id="uniclos-order-consumer",
        value_deserializer=lambda m: json.loads(m.decode("utf-8")),
    )

    dlq_producer = KafkaProducer(
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        value_serializer=lambda v: json.dumps(v).encode("utf-8"),
    )

    consumed = 0
    failed = 0
    messages_read = 0

    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = True

    try:
        with conn.cursor() as cur:
            for message in consumer:
                messages_read += 1
                if messages_read > CONSUMER_MAX_MESSAGES:
                    break

                payload = message.value
                topic = message.topic
                is_valid, error = validate_order_event(payload)

                if not is_valid:
                    failed += 1
                    cur.execute(
                        """
                        INSERT INTO raw.failed_events (source_topic, payload, error_reason)
                        VALUES (%s, %s, %s)
                        """,
                        (topic, Json(payload), error),
                    )
                    dlq_producer.send(TOPIC_ORDERS_DLQ, {"original": payload, "error": error})
                    continue

                cur.execute(
                    """
                    INSERT INTO raw.streaming_orders (
                        order_id, source_topic, channel, store_code, customer_email,
                        product_ref, quantity, unit_price_eur, amount_eur,
                        order_timestamp, payload, processed
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, FALSE)
                    ON CONFLICT (order_id) DO NOTHING
                    """,
                    (
                        payload["order_id"],
                        topic,
                        payload.get("channel"),
                        payload.get("store_code"),
                        payload.get("customer_email"),
                        payload.get("product_ref"),
                        payload.get("quantity"),
                        payload.get("unit_price_eur"),
                        payload.get("amount_eur"),
                        _parse_timestamp(payload["order_timestamp"]),
                        Json(payload),
                    ),
                )
                if cur.rowcount:
                    consumed += 1
    finally:
        consumer.close()
        dlq_producer.flush()
        dlq_producer.close()
        conn.close()

    summary = {
        "events_consumed": consumed,
        "events_failed": failed,
        "messages_read": messages_read,
    }
    logger.info("Consumer summary: %s", summary)
    return summary


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print(consume_to_raw())
