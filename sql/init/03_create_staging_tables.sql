-- UNICLOTHES: Staging layer - golden record preparation

CREATE TABLE IF NOT EXISTS staging.customers_unified (
    staging_id          SERIAL PRIMARY KEY,
    source_id           VARCHAR(50),
    source_system       VARCHAR(20),
    email_normalized    VARCHAR(255),
    email               VARCHAR(255),
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    phone               VARCHAR(30),
    consent_marketing   BOOLEAN,
    consent_date        DATE,
    last_activity       DATE,
    store_code          VARCHAR(10),
    source_priority     INTEGER,
    loaded_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS staging.customers_golden (
    customer_key        SERIAL PRIMARY KEY,
    golden_id           UUID DEFAULT uuid_generate_v4(),
    email_normalized    VARCHAR(255) UNIQUE,
    email               VARCHAR(255),
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    phone               VARCHAR(30),
    consent_marketing   BOOLEAN,
    consent_date        DATE,
    last_activity       DATE,
    is_active_12m       BOOLEAN,
    email_valid         BOOLEAN,
    duplicate_count     INTEGER DEFAULT 1,
    merged_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS staging.products_unified (
    staging_id          SERIAL PRIMARY KEY,
    source_ref          VARCHAR(30),
    source_system       VARCHAR(20),
    product_ref         VARCHAR(30),
    product_name        VARCHAR(200),
    category            VARCHAR(50),
    price_eur           NUMERIC(10,2),
    stock_qty           INTEGER,
    source_priority     INTEGER,
    loaded_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS staging.products_golden (
    product_key         SERIAL PRIMARY KEY,
    product_ref         VARCHAR(30) UNIQUE,
    product_name        VARCHAR(200),
    category            VARCHAR(50),
    price_eur           NUMERIC(10,2),
    stock_qty           INTEGER,
    image_object_key    VARCHAR(120),
    merged_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS staging.orders_unified (
    order_id            VARCHAR(50) PRIMARY KEY,
    customer_email      VARCHAR(255),
    channel             VARCHAR(10),
    store_code          VARCHAR(10),
    order_date          TIMESTAMP,
    product_ref         VARCHAR(30),
    quantity            INTEGER,
    unit_price_eur      NUMERIC(10,2),
    amount_eur          NUMERIC(10,2)
);

-- Quality metrics table for monitoring
CREATE TABLE IF NOT EXISTS staging.quality_metrics (
    metric_id           SERIAL PRIMARY KEY,
    metric_name         VARCHAR(100),
    metric_value        NUMERIC(10,4),
    target_value        NUMERIC(10,4),
    measured_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status              VARCHAR(20)
);
