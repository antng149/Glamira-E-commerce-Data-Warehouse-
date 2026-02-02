-- models/staging/stg_sales_orders.sql

WITH source AS (
    SELECT * FROM {{ source('glamira_countly', 'summary_final_v6') }}
)

,unnested_cart AS (
    SELECT
        -- Identifiers
        source.mongo_id
        ,source.order_id
        
        -- Customer identifiers
        ,source.device_id
        ,COALESCE(source.user_id_db, source.device_id) AS user_id
        ,source.email_address AS email
        
        -- Location data
        ,source.ip AS ip_address
        
        -- Store information
        ,source.store_id
        
        -- Timestamps
        ,source.time_stamp
        ,source.collection AS event_collection
        
        -- Session data
        ,source.user_agent
        ,source.current_url
        ,source.referrer_url
        
        -- Unnest cart_products to get individual items
        ,cart_item.product_id
        ,cart_item.price
        ,cart_item.amount AS quantity
        ,cart_item.currency
        
    FROM source
    ,UNNEST(cart_products) AS cart_item
    
    -- Less aggressive filtering - only filter on collection and keep records with order_id
    WHERE source.collection = 'checkout_success'
        AND source.order_id IS NOT NULL
)

,cleaned AS (
    SELECT
        -- Identifiers
        mongo_id
        ,order_id
        
        -- Customer identifiers
        ,device_id
        ,user_id
        ,email
        
        -- Location data
        ,ip_address
        
        -- Product information (Strict CAST)
        ,CAST(product_id AS int64) AS product_id
        
        -- Store information
        ,store_id
        
        -- Transaction details - Universal price cleaning with strict CAST
        ,CASE
            -- Skip if price is NULL or empty
            WHEN price IS NULL OR TRIM(price) = '' THEN NULL
            
            -- Comma as decimal (European format): "1.234,56" or "47,00"
            WHEN REGEXP_CONTAINS(price, r',\d{1,2}$') THEN
                CAST(
                    REPLACE(
                        REGEXP_REPLACE(price, r"[^0-9,]", ''),
                        ',', '.'
                    ) AS float64
                )
            
            -- Period as decimal (US/UK format): "1,234.56" or "47.00"  
            WHEN REGEXP_CONTAINS(price, r'\.\d{1,2}$') THEN
                CAST(
                    REGEXP_REPLACE(price, r"[^0-9.]", '')
                    AS float64
                )
            
            -- No clear decimal, remove everything except digits
            ELSE
                CAST(
                    REGEXP_REPLACE(price, r"[^0-9]", '')
                    AS float64
                )
        END AS price_original

        ,CAST(quantity AS int64) AS quantity
        
        -- Normalize currency codes
        ,CASE
            WHEN currency IN ('$', '$US', 'US $', 'US$', 'USD', 'USD $', 'dolar', 'долл США') THEN 'USD'
            WHEN currency IN ('$ CAD', 'CAD $', '加元', '加币$') THEN 'CAD'
            WHEN currency IN ('EUR', '€', 'евро', 'يورو') THEN 'EUR'
            WHEN currency = '£' THEN 'GBP'
            WHEN currency IN ('AU $', 'AUD $') THEN 'AUD'
            WHEN currency = 'NZD $' THEN 'NZD'
            WHEN currency IN ('CHF', "CHF '", 'швейцарских франка', 'швейцарских франков') THEN 'CHF'
            WHEN currency IN ('SEK', 'kr', 'шведских крон', '瑞典克朗', '، كرونة') THEN 'SEK'
            WHEN currency IN ('PLN', 'zł', 'зл', 'злотых') THEN 'PLN'
            WHEN currency IN ('CZK', 'Kč') THEN 'CZK'
            WHEN currency = 'Ft' THEN 'HUF'
            WHEN currency IN ('RON', 'Lei') THEN 'RON'
            WHEN currency IN ('BGN', 'лв') THEN 'BGN'
            WHEN currency = 'kn' THEN 'HRK'
            WHEN currency = 'din' THEN 'RSD'
            WHEN currency = '₴' THEN 'UAH'
            WHEN currency = '₺' THEN 'TRY'
            WHEN currency = 'דולר' THEN 'ILS'
            WHEN currency IN ('AED', '، درهم') THEN 'AED'
            WHEN currency = 'د ك' THEN 'KWD'
            WHEN currency IN ('MXN', 'MXN $') THEN 'MXN'
            WHEN currency = 'R$' THEN 'BRL'
            WHEN currency = 'CLP' THEN 'CLP'
            WHEN currency = 'COP $' THEN 'COP'
            WHEN currency IN ('PEN S', 'PEN S/') THEN 'PEN'
            WHEN currency = 'BOB Bs' THEN 'BOB'
            WHEN currency = 'UYU' THEN 'UYU'
            WHEN currency = 'CRC ₡' THEN 'CRC'
            WHEN currency = 'GTQ Q' THEN 'GTQ'
            WHEN currency = 'DOP $' THEN 'DOP'
            WHEN currency = 'HNL L' THEN 'HNL'
            WHEN currency = '₲' THEN 'PYG'
            WHEN currency = 'SGD $' THEN 'SGD'
            WHEN currency IN ('HKD $', '港币$') THEN 'HKD'
            WHEN currency = 'NT$' THEN 'TWD'
            WHEN currency IN ('¥', '￥') THEN 'CNY'
            WHEN currency = '₩' THEN 'KRW'
            WHEN currency = '฿' THEN 'THB'
            WHEN currency IN ('VND', '₫') THEN 'VND'
            WHEN currency = '₱' THEN 'PHP'
            WHEN currency = '₹' THEN 'INR'
            WHEN currency = 'Rp' THEN 'IDR'
            WHEN currency = 'RM' THEN 'MYR'
            WHEN currency = 'ZAR' THEN 'ZAR'
            WHEN currency = 'KMF' THEN 'KMF'
            WHEN currency = 'Lekë' THEN 'ALL'
            WHEN currency = 'AZN' THEN 'AZN'
            WHEN currency = 'AFN' THEN 'AFN'
            WHEN currency = 'Ucretsiz' THEN NULL
            ELSE 'USD'
        END AS currency_code
        
        ,FALSE AS is_paypal
        
        -- Timestamps
        ,TIMESTAMP_SECONDS(CAST(time_stamp AS int64)) AS event_ts
        ,DATE(TIMESTAMP_SECONDS(CAST(time_stamp AS int64))) AS order_date
        
        -- Session data
        ,user_agent
        ,event_collection
        
        -- URL validation - only keep valid HTTP/HTTPS URLs
        ,CASE 
            WHEN current_url LIKE 'http://%' OR current_url LIKE 'https://%' 
            THEN current_url 
            ELSE NULL 
        END AS current_url
        
        ,CASE 
            WHEN referrer_url LIKE 'http://%' OR referrer_url LIKE 'https://%' 
            THEN referrer_url 
            ELSE NULL 
        END AS referrer_url
        
    FROM unnested_cart
)
    
,final AS (
    SELECT *
    FROM cleaned
    -- Filter logic for quality control
    WHERE price_original IS NOT NULL
        AND price_original >= 0 
        AND quantity IS NOT NULL
        AND quantity > 0
        AND product_id IS NOT NULL
)

SELECT * FROM final