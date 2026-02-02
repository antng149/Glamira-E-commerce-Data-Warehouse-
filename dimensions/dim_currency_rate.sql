-- models/dimensions/dim_currency_rate.sql

{{ config(
    materialized = 'table'
) }}

WITH currency_rates AS (
    SELECT * FROM {{ ref('currency_rates') }}
)

SELECT 
    CAST(currency_code AS string) AS currency_code
    ,currency_name
    ,CAST(exchange_rate_to_usd AS numeric) AS exchange_rate_to_usd
    ,effective_date
    
FROM currency_rates