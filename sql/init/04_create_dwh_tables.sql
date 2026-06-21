-- UNICLOTHES: Data warehouse star schema

CREATE TABLE IF NOT EXISTS dwh.dim_date (
    date_key        INTEGER PRIMARY KEY,
    full_date       DATE UNIQUE NOT NULL,
    day_of_week     INTEGER,
    day_name        VARCHAR(10),
    week_of_year    INTEGER,
    month_num       INTEGER,
    month_name      VARCHAR(10),
    quarter_num     INTEGER,
    year_num        INTEGER
);

CREATE TABLE IF NOT EXISTS dwh.dim_channel (
    channel_key     SERIAL PRIMARY KEY,
    channel_code    VARCHAR(10) UNIQUE NOT NULL,
    channel_name    VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS dwh.dim_store (
    store_key       SERIAL PRIMARY KEY,
    store_code      VARCHAR(10) UNIQUE NOT NULL,
    store_name      VARCHAR(100),
    city            VARCHAR(50),
    region          VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS dwh.dim_customer (
    customer_key        SERIAL PRIMARY KEY,
    golden_id           UUID UNIQUE,
    email               VARCHAR(255),
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    phone               VARCHAR(30),
    consent_marketing   BOOLEAN,
    consent_date        DATE,
    last_activity       DATE,
    is_active_12m       BOOLEAN,
    email_valid         BOOLEAN,
    valid_from          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_to            TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dwh.dim_product (
    product_key         SERIAL PRIMARY KEY,
    product_ref         VARCHAR(30) UNIQUE NOT NULL,
    product_name        VARCHAR(200),
    category            VARCHAR(50),
    price_eur           NUMERIC(10,2),
    stock_qty           INTEGER,
    image_object_key    VARCHAR(120),
    image_url           VARCHAR(500)
);

CREATE TABLE IF NOT EXISTS dwh.fact_sales (
    order_id        VARCHAR(50) PRIMARY KEY,
    date_key        INTEGER REFERENCES dwh.dim_date(date_key),
    customer_key    INTEGER REFERENCES dwh.dim_customer(customer_key),
    product_key     INTEGER REFERENCES dwh.dim_product(product_key),
    store_key       INTEGER REFERENCES dwh.dim_store(store_key),
    channel_key     INTEGER REFERENCES dwh.dim_channel(channel_key),
    quantity        INTEGER NOT NULL,
    unit_price_eur  NUMERIC(10,2),
    amount_eur      NUMERIC(10,2) NOT NULL,
    order_timestamp TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_fact_sales_date ON dwh.fact_sales(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_customer ON dwh.fact_sales(customer_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_product ON dwh.fact_sales(product_key);
