-- models/dimensions/dim_store.sql

{{ config(
    materialized = 'table'
) }}

WITH orders AS (
    SELECT * FROM {{ ref('stg_sales_orders') }}
)

,stores AS (
    SELECT DISTINCT
        store_id
    FROM orders
    WHERE store_id IS NOT NULL
)

SELECT 
    CAST(store_id AS string) AS store_id
    ,CONCAT('Store ', CAST(store_id AS string)) AS store_name
FROM stores