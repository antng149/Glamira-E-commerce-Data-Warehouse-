-- models/staging/stg_ip_locations.sql

WITH source AS (
    SELECT * FROM {{ source('glamira_countly', 'ip_locations') }}
)

,cleaned AS (
    SELECT
        ip AS ip_address
        ,country_long AS country_name
        ,region AS region_name
        ,city AS city_name
        
        -- Generate location_key (same hash as dim_location)
        ,CAST(CONCAT('0x', SUBSTR({{ dbt_utils.generate_surrogate_key(['country_long', 'region', 'city']) }}, 1, 15)) AS int64) AS location_key
        
    FROM source
    WHERE ip IS NOT NULL
)

SELECT * FROM cleaned