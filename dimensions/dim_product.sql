-- models/dimensions/dim_product.sql

{{ config(
    materialized = 'table'
) }}

WITH products AS (
    SELECT * FROM {{ ref('stg_products') }}
)

,product_dimension AS (
    SELECT
        -- Hash surrogate key
        CAST(CONCAT('0x', SUBSTR({{ dbt_utils.generate_surrogate_key(['product_id']) }}, 1, 15)) AS int64) AS product_key
        
        -- Natural key and attributes (keep product_id as INT64, not STRING)
        ,product_id  -- ✅ Keep as INT64 for proper JOINs
        ,product_name
        ,sku
        ,collection
        ,product_type
        ,category
        ,gender
        ,min_price_original AS min_price
        ,max_price_original AS max_price
        ,price_currency
        
    FROM products
)

SELECT * FROM product_dimension