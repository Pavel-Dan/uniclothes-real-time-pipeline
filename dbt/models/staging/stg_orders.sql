-- Commandes temps reel non encore traitees vers le DWH

SELECT
    order_id,
    customer_email,
    channel,
    store_code,
    product_ref,
    quantity,
    unit_price_eur,
    amount_eur,
    order_timestamp
FROM {{ source('raw', 'streaming_orders') }}
WHERE processed = FALSE
