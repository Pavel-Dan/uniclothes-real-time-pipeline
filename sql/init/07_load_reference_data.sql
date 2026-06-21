-- Uniclos Bloc3: charge initiale referentiels (pas les commandes historiques)

\echo 'Loading reference seed data...'

\copy raw.customers_crm(source_id,email,first_name,last_name,phone,consent_marketing,consent_date,last_activity) FROM '/seed/customers_crm.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy raw.customers_web(source_id,email,first_name,last_name,phone,consent_marketing,consent_date,last_activity) FROM '/seed/customers_web.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy raw.customers_pos(source_id,email,first_name,last_name,phone,consent_marketing,consent_date,last_activity,store_code) FROM '/seed/customers_pos.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy raw.products_erp(product_ref,product_name,category,price_eur,stock_qty) FROM '/seed/products_erp.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy raw.products_web(web_sku,product_ref,product_name,category,price_eur) FROM '/seed/products_web.csv' WITH (FORMAT csv, HEADER true, NULL '');
\copy raw.stores(store_code,store_name,city,region,opened_date) FROM '/seed/stores.csv' WITH (FORMAT csv, HEADER true, NULL '');

-- Golden record clients
INSERT INTO staging.customers_unified
    (source_id, source_system, email_normalized, email, first_name, last_name,
     phone, consent_marketing, consent_date, last_activity, store_code, source_priority)
SELECT source_id, 'crm', LOWER(TRIM(email)), email, first_name, last_name, phone,
       consent_marketing, consent_date, last_activity, NULL, 1
FROM raw.customers_crm;

INSERT INTO staging.customers_unified
    (source_id, source_system, email_normalized, email, first_name, last_name,
     phone, consent_marketing, consent_date, last_activity, store_code, source_priority)
SELECT source_id, 'web', LOWER(TRIM(email)), email, first_name, last_name, phone,
       consent_marketing, consent_date, last_activity, NULL, 2
FROM raw.customers_web;

INSERT INTO staging.customers_unified
    (source_id, source_system, email_normalized, email, first_name, last_name,
     phone, consent_marketing, consent_date, last_activity, store_code, source_priority)
SELECT source_id, 'pos', LOWER(TRIM(email)), email, first_name, last_name, phone,
       consent_marketing, consent_date, last_activity, store_code, 3
FROM raw.customers_pos;

INSERT INTO staging.customers_golden
    (email_normalized, email, first_name, last_name, phone,
     consent_marketing, consent_date, last_activity, is_active_12m, email_valid, duplicate_count)
SELECT DISTINCT ON (cu.email_normalized)
    cu.email_normalized, cu.email, cu.first_name, cu.last_name, cu.phone,
    cu.consent_marketing, cu.consent_date, cu.last_activity,
    (cu.last_activity >= CURRENT_DATE - INTERVAL '12 months'),
    (cu.email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    cnt.duplicate_count
FROM staging.customers_unified cu
JOIN (
    SELECT email_normalized, COUNT(*) AS duplicate_count
    FROM staging.customers_unified
    WHERE email_normalized IS NOT NULL AND email_normalized <> ''
    GROUP BY email_normalized
) cnt ON cu.email_normalized = cnt.email_normalized
WHERE cu.email_normalized IS NOT NULL AND cu.email_normalized <> ''
ORDER BY cu.email_normalized, cu.source_priority ASC, cu.last_activity DESC NULLS LAST;

-- Golden record produits (ERP master)
INSERT INTO staging.products_unified
    (source_ref, source_system, product_ref, product_name, category, price_eur, stock_qty, source_priority)
SELECT product_ref, 'erp', product_ref, product_name, category, price_eur, stock_qty, 1
FROM raw.products_erp;

INSERT INTO staging.products_unified
    (source_ref, source_system, product_ref, product_name, category, price_eur, stock_qty, source_priority)
SELECT web_sku, 'web', product_ref, product_name, category, price_eur, NULL, 2
FROM raw.products_web;

INSERT INTO staging.products_golden (product_ref, product_name, category, price_eur, stock_qty, image_object_key)
SELECT DISTINCT ON (product_ref)
    product_ref, product_name, category, price_eur, stock_qty, product_ref || '.jpg'
FROM staging.products_unified
WHERE product_ref IS NOT NULL
ORDER BY product_ref, source_priority ASC;

-- Dimensions
INSERT INTO dwh.dim_date (date_key, full_date, day_of_week, day_name, week_of_year, month_num, month_name, quarter_num, year_num)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER, d,
    EXTRACT(DOW FROM d)::INTEGER, TO_CHAR(d, 'Day'),
    EXTRACT(WEEK FROM d)::INTEGER, EXTRACT(MONTH FROM d)::INTEGER, TO_CHAR(d, 'Month'),
    EXTRACT(QUARTER FROM d)::INTEGER, EXTRACT(YEAR FROM d)::INTEGER
FROM generate_series(CURRENT_DATE - 400, CURRENT_DATE + 30, '1 day'::interval) AS d
ON CONFLICT (full_date) DO NOTHING;

INSERT INTO dwh.dim_channel (channel_code, channel_name) VALUES
    ('web', 'Site e-commerce'),
    ('app', 'Application mobile'),
    ('store', 'Boutique physique')
ON CONFLICT (channel_code) DO NOTHING;

INSERT INTO dwh.dim_store (store_code, store_name, city, region)
SELECT store_code, store_name, city, region FROM raw.stores
ON CONFLICT (store_code) DO UPDATE SET
    store_name = EXCLUDED.store_name, city = EXCLUDED.city, region = EXCLUDED.region;

INSERT INTO dwh.dim_store (store_code, store_name, city, region) VALUES
    ('ONLINE', 'En ligne', 'Paris', 'National')
ON CONFLICT (store_code) DO NOTHING;

INSERT INTO dwh.dim_customer
    (golden_id, email, first_name, last_name, phone, consent_marketing,
     consent_date, last_activity, is_active_12m, email_valid)
SELECT golden_id, email, first_name, last_name, phone, consent_marketing,
       consent_date, last_activity, is_active_12m, email_valid
FROM staging.customers_golden;

INSERT INTO dwh.dim_product (product_ref, product_name, category, price_eur, stock_qty, image_object_key, image_url)
SELECT product_ref, product_name, category, price_eur, stock_qty, image_object_key,
       'http://localhost:9000/product-images/' || image_object_key
FROM staging.products_golden;

\echo 'Reference data loaded. Streaming pipeline will populate fact_sales.';
