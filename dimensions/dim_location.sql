-- models/dimensions/dim_location.sql

{{ config(
    materialized = 'table'
) }}

WITH locations AS (
    SELECT * FROM {{ ref('stg_ip_locations') }}
)

,location_dimension AS (
    SELECT DISTINCT
        -- Hash surrogate key
        CAST(CONCAT('0x', SUBSTR({{ dbt_utils.generate_surrogate_key(['country_name', 'region_name', 'city_name']) }}, 1, 15)) AS int64) AS location_key
        
        -- Location attributes
        ,country_name
        ,region_name
        ,city_name
        
    FROM locations
)

SELECT * FROM location_dimension