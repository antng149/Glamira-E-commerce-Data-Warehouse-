-- models/dimensions/dim_customer.sql

{{ config(
    materialized = 'table'
) }}

WITH orders AS (
    SELECT * FROM {{ ref('stg_sales_orders') }}
)

,customers AS (
    SELECT DISTINCT
        user_id
        ,FIRST_VALUE(email) OVER (PARTITION BY user_id ORDER BY event_ts DESC) AS email
        ,FIRST_VALUE(device_id) OVER (PARTITION BY user_id ORDER BY event_ts DESC) AS device_id
        ,FIRST_VALUE(user_agent) OVER (PARTITION BY user_id ORDER BY event_ts DESC) AS user_agent
    FROM orders
    WHERE user_id IS NOT NULL
)

SELECT DISTINCT
    CAST(user_id AS string) AS user_id
    ,email
    ,device_id
    ,user_agent
FROM customers