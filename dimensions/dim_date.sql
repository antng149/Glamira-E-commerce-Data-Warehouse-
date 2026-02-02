-- models/dimensions/dim_date.sql

{{ config(
    materialized = 'table'
) }}

WITH date_spine AS (
    {{ dbt_utils.date_spine(
        datepart = "day"
        ,start_date = "CAST('2020-01-01' AS date)"
        ,end_date = "CAST('2030-12-31' AS date)"
    ) }}
)

,date_dimension AS (
    SELECT
        -- Primary Key for joining with Fact tables
        FORMAT_DATE('%Y%m%d', date_day) AS date_key
        ,date_day
        
        -- Date Parts
        ,EXTRACT(year FROM date_day) AS year
        ,EXTRACT(quarter FROM date_day) AS quarter
        ,EXTRACT(month FROM date_day) AS month
        ,EXTRACT(day FROM date_day) AS day
        
        -- Calendar Names for Dashboards
        ,FORMAT_DATE('%B', date_day) AS month_name        -- e.g., 'January'
        ,FORMAT_DATE('%A', date_day) AS day_name          -- e.g., 'Monday'
        
        -- Day of week (1=Sunday, 7=Saturday in BigQuery)
        ,EXTRACT(dayofweek FROM date_day) AS day_of_week
        
        -- Weekend Flag for performance analysis
        ,CASE 
            WHEN EXTRACT(dayofweek FROM date_day) IN (1, 7) THEN TRUE 
            ELSE FALSE 
        END AS is_weekend
        
    FROM date_spine
)

SELECT * FROM date_dimension