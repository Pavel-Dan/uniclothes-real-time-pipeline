-- Clients distincts issus du flux streaming (enrichissement golden record)

SELECT DISTINCT
    LOWER(TRIM(customer_email)) AS email_normalized,
    customer_email AS email,
    MAX(order_timestamp) AS last_order_at
FROM {{ source('raw', 'streaming_orders') }}
WHERE customer_email IS NOT NULL
GROUP BY 1, 2
