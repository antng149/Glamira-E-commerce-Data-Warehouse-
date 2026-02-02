-- models/staging/stg_products.sql

WITH source AS (
    SELECT * FROM {{ source('glamira_project6', 'products_raw') }}
    WHERE product_id IS NOT NULL  -- Filter out bad source data with NULL product_ids
)

,deduplicated AS (
    SELECT * FROM (
        SELECT 
            *,
            ROW_NUMBER() OVER (
                PARTITION BY CAST(product_id AS INT64) 
                ORDER BY 
                    CASE WHEN min_price IS NOT NULL THEN 1 ELSE 2 END,
                    COALESCE(price, 0) DESC
            ) AS rn
        FROM source
    )
    WHERE rn = 1
)

,base_products AS (
    SELECT
        CAST(product_id AS int64) AS product_id
        ,COALESCE(product_name, 'Unknown Product') AS product_name
        ,COALESCE(sku, 'UNKNOWN') AS sku
        ,CAST(collection AS STRING) AS collection
        ,CAST(product_type AS STRING) AS product_type
        ,CAST(category AS STRING) AS category
        ,CAST(gender AS STRING) AS gender
        ,COALESCE(CAST(min_price AS float64), 0.0) AS min_price_original
        ,COALESCE(CAST(max_price AS float64), 0.0) AS max_price_original
        ,CASE 
            WHEN min_price_format LIKE '%€%' THEN 'EUR'
            WHEN min_price_format LIKE '%$%' THEN 'USD'
            ELSE 'EUR'
        END AS price_currency
    FROM deduplicated
)

,unknown_member AS (
    -- Unknown member for products that exist in orders but not in catalog
    SELECT
        -1 AS product_id
        ,'Unknown / Discontinued Product' AS product_name
        ,'UNKNOWN' AS sku
        ,CAST(NULL AS STRING) AS collection
        ,CAST(NULL AS STRING) AS product_type
        ,CAST(NULL AS STRING) AS category
        ,CAST(NULL AS STRING) AS gender
        ,0.0 AS min_price_original
        ,0.0 AS max_price_original
        ,'USD' AS price_currency
)

SELECT * FROM base_products
UNION ALL
SELECT * FROM unknown_member