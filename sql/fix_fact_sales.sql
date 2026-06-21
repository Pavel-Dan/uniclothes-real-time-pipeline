-- One-shot repair: align fact_sales with dbt incremental model (no sales_key)
DROP TABLE IF EXISTS dwh.fact_sales CASCADE;

CREATE TABLE dwh.fact_sales (
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

CREATE OR REPLACE VIEW dwh.v_sales_analytics AS
SELECT
    fs.order_id,
    dd.full_date,
    dd.month_name,
    dd.year_num,
    dca.email_masked,
    dca.is_active_12m,
    dca.consent_marketing,
    dp.product_ref,
    dp.product_name,
    dp.category,
    ds.store_name,
    dch.channel_name,
    fs.quantity,
    fs.amount_eur
FROM dwh.fact_sales fs
JOIN dwh.dim_date dd ON fs.date_key = dd.date_key
JOIN dwh.dim_customer_anonymized dca ON fs.customer_key = dca.customer_key
JOIN dwh.dim_product dp ON fs.product_key = dp.product_key
JOIN dwh.dim_store ds ON fs.store_key = ds.store_key
JOIN dwh.dim_channel dch ON fs.channel_key = dch.channel_key;

GRANT SELECT ON dwh.v_sales_analytics TO uniclothes_analyst;
