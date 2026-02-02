-- models/facts/fact_sales_order_tt.sql

{{ config(
    materialized = 'table'
) }}

WITH orders AS (
    SELECT * FROM {{ ref('stg_sales_orders') }}
)

,products AS (
    SELECT * FROM {{ ref('dim_product') }}
)

,ip_locations AS (
    SELECT * FROM {{ ref('stg_ip_locations') }}
)

,currency_rates AS (
    SELECT * FROM {{ ref('dim_currency_rate') }}
)

,fact_table AS (
    SELECT
        -- Hash surrogate key for fact table
        CAST(CONCAT('0x', SUBSTR({{ dbt_utils.generate_surrogate_key(['orders.mongo_id', 'orders.product_id']) }}, 1, 15)) AS int64) AS sales_order_item_key

        -- Foreign keys to dimensions
        ,FORMAT_DATE('%Y%m%d', orders.order_date) AS date_key
        
        -- Use COALESCE to map missing products to the Unknown member (-1)
        ,COALESCE(products.product_key, -1) AS product_key
        
        ,CAST(orders.user_id AS string) AS user_id
        ,CAST(orders.store_id AS string) AS store_id
        ,ip_locations.location_key
        
        -- Transaction details
        ,CAST(orders.order_id AS string) AS order_id
        ,orders.ip_address
        ,orders.order_date
        
        -- Metrics
        ,CAST(orders.quantity AS numeric) AS quantity
        ,CAST(orders.price_original AS numeric) AS price_original
        ,CAST(orders.currency_code AS string) AS currency_code
        
        -- Convert to USD
        ,CAST(orders.price_original * COALESCE(currency_rates.exchange_rate_to_usd, 1.0) AS numeric) AS price_usd
        ,CAST((orders.price_original * COALESCE(currency_rates.exchange_rate_to_usd, 1.0)) * orders.quantity AS numeric) AS line_total_usd
        
        -- Payment method
        ,orders.is_paypal
        
        -- Timestamp
        ,orders.event_ts
        
    FROM orders
    LEFT JOIN products 
        ON orders.product_id = products.product_id  -- ✅ Both are INT64 now
    LEFT JOIN ip_locations 
        ON orders.ip_address = ip_locations.ip_address
    LEFT JOIN currency_rates 
        ON orders.currency_code = currency_rates.currency_code
    
    WHERE orders.order_id IS NOT NULL
)

SELECT * FROM fact_table