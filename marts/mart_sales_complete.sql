-- models/marts/mart_sales_complete.sql

{{ config(
    materialized = 'table',
    partition_by = {
        'field': 'order_date',
        'data_type': 'date',
        'granularity': 'day'
    }
) }}

WITH fact AS (
    SELECT * FROM {{ ref('fact_sales_order_tt') }}
)

,products AS (
    SELECT * FROM {{ ref('dim_product') }}
)

,customers AS (
    SELECT * FROM {{ ref('dim_customer') }}
)

,stores AS (
    SELECT * FROM {{ ref('dim_store') }}
)

,locations AS (
    SELECT * FROM {{ ref('dim_location') }}
)

,dates AS (
    SELECT * FROM {{ ref('dim_date') }}
)

,currency_rates AS (
    SELECT * FROM {{ ref('dim_currency_rate') }}
)

,sales_mart AS (
    SELECT
        -- Primary Key
        fact.sales_order_item_key,
        
        -- Order Information
        fact.order_id,
        fact.ip_address,
        fact.event_ts,
        
        -- Date Dimensions
        fact.order_date,
        dates.date_key,
        dates.year AS order_year,
        dates.quarter AS order_quarter,
        dates.month AS order_month,
        dates.month_name AS order_month_name,
        dates.day AS order_day,
        dates.day_of_week,
        dates.day_name,
        dates.is_weekend,
        
        -- Product Dimensions
        fact.product_key,
        products.product_id,
        products.product_name,
        products.sku,
        products.collection,
        products.product_type,
        products.category,
        products.gender,
        products.min_price AS product_min_price,
        products.max_price AS product_max_price,
        products.price_currency AS product_currency,
        
        -- Customer Dimensions
        fact.user_id,
        customers.email,
        customers.device_id,
        customers.user_agent,
        customers.first_order_date AS customer_first_order_date,
        customers.total_orders AS customer_lifetime_orders,
        
        -- Customer Metrics
        CASE 
            WHEN fact.order_date = customers.first_order_date THEN TRUE 
            ELSE FALSE 
        END AS is_first_order,
        
        DATE_DIFF(fact.order_date, customers.first_order_date, DAY) AS days_since_first_order,
        
        -- Store Dimensions
        fact.store_id,
        stores.store_name,
        stores.store_domain,
        stores.country AS store_country,
        
        -- Location Dimensions (only 3 fields)
        fact.location_key,
        locations.country_name AS customer_country,
        locations.region_name AS customer_region,
        locations.city_name AS customer_city,
        
        -- Currency Information
        fact.currency_code,
        currency_rates.exchange_rate_to_usd,
        
        -- Transaction Metrics
        fact.quantity,
        fact.price_original,
        fact.price_usd,
        fact.line_total_usd,
        
        -- Calculated Metrics
        CASE 
            WHEN fact.quantity > 0 THEN fact.price_usd / fact.quantity 
            ELSE NULL 
        END AS unit_price_usd,
        
        -- Flags
        fact.is_paypal,
        CASE WHEN fact.product_key = -1 THEN TRUE ELSE FALSE END AS is_unknown_product,
        CASE WHEN fact.price_original = 0 THEN TRUE ELSE FALSE END AS is_free_item
        
    FROM fact
    LEFT JOIN products ON fact.product_key = products.product_key
    LEFT JOIN customers ON fact.user_id = customers.user_id
    LEFT JOIN stores ON fact.store_id = stores.store_id
    LEFT JOIN locations ON fact.location_key = locations.location_key
    LEFT JOIN dates ON fact.date_key = dates.date_key
    LEFT JOIN currency_rates ON fact.currency_code = currency_rates.currency_code
)

SELECT * FROM sales_mart