{{
    config(
        materialized='incremental',
        unique_key='order_id',
        alias='fact_sales',
        schema='dwh',
        incremental_strategy='append',
        on_schema_change='ignore'
    )
}}

SELECT
    o.order_id,
    TO_CHAR(o.order_timestamp::DATE, 'YYYYMMDD')::INTEGER AS date_key,
    dc.customer_key,
    dp.product_key,
    COALESCE(ds.store_key, online_store.store_key) AS store_key,
    dch.channel_key,
    o.quantity,
    o.unit_price_eur,
    o.amount_eur,
    o.order_timestamp AS order_timestamp
FROM {{ ref('stg_orders') }} o
INNER JOIN dwh.dim_date dd
    ON dd.date_key = TO_CHAR(o.order_timestamp::DATE, 'YYYYMMDD')::INTEGER
LEFT JOIN dwh.dim_customer dc
    ON LOWER(TRIM(o.customer_email)) = LOWER(TRIM(dc.email))
LEFT JOIN dwh.dim_product dp
    ON o.product_ref = dp.product_ref
LEFT JOIN dwh.dim_store ds
    ON o.store_code = ds.store_code
LEFT JOIN dwh.dim_store online_store
    ON online_store.store_code = 'ONLINE'
LEFT JOIN dwh.dim_channel dch
    ON o.channel = dch.channel_code
WHERE dc.customer_key IS NOT NULL
  AND dp.product_key IS NOT NULL
  AND dch.channel_key IS NOT NULL
  AND COALESCE(ds.store_key, online_store.store_key) IS NOT NULL

{% if is_incremental() %}
  AND NOT EXISTS (
      SELECT 1 FROM {{ this }} existing WHERE existing.order_id = o.order_id
  )
{% endif %}
