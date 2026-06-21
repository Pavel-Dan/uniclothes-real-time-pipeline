-- Uniclos Bloc3: streaming landing zone and dead-letter queue

CREATE TABLE IF NOT EXISTS raw.streaming_orders (
    event_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id        VARCHAR(50) NOT NULL,
    source_topic    VARCHAR(80),
    channel         VARCHAR(10),
    store_code      VARCHAR(10),
    customer_email  VARCHAR(255),
    product_ref     VARCHAR(30),
    quantity        INTEGER,
    unit_price_eur  NUMERIC(10,2),
    amount_eur      NUMERIC(10,2),
    order_timestamp TIMESTAMP NOT NULL,
    payload         JSONB,
    consumed_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed       BOOLEAN DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_streaming_orders_order_id
    ON raw.streaming_orders (order_id);

CREATE TABLE IF NOT EXISTS raw.failed_events (
    failed_id       BIGSERIAL PRIMARY KEY,
    source_topic    VARCHAR(80),
    payload         JSONB,
    error_reason    TEXT,
    failed_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE raw.streaming_orders IS 'Landing zone evenements commandes temps reel (Redpanda)';
COMMENT ON TABLE raw.failed_events IS 'Dead-letter queue persistee pour messages invalides';
