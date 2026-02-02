> 📖 **[Đọc phiên bản tiếng Việt / Read Vietnamese version](READM_VI.md)**

# Glamira E-commerce Data Warehouse Project

---

## Table of Contents
- [Executive Summary](#executive-summary)
- [Project Objectives](#project-objectives)
- [Technical Architecture](#technical-architecture)
- [Data Sources & Quality](#data-sources--quality)
- [Implementation Journey](#implementation-journey)
- [Major Challenges & Solutions](#major-challenges--solutions)
- [Key Learnings](#key-learnings)
- [Project Outcomes](#project-outcomes)
- [Data Model Documentation](#data-model-documentation)
- [Query Examples](#query-examples)
- [Dashboard Setup Guide](#dashboard-setup-guide)
- [Maintenance & Operations](#maintenance--operations)
- [Future Enhancements](#future-enhancements)
- [Appendix](#appendix)

---

## Executive Summary

This project builds a production-ready data warehouse for Glamira, an international jewelry e-commerce company. The warehouse consolidates transaction data from 65 stores across multiple countries, processes 35,000+ transactions, and enables business intelligence through dimensional modeling and data marts.

### Key Achievements
- ✅ **35,064 transactions** processed from raw MongoDB events
- ✅ **52 currencies** normalized to USD for consistent reporting
- ✅ **82 data quality tests** with 99% pass rate
- ✅ **4-layer architecture** (staging → dimensions → facts → marts)
- ✅ **Sub-second query performance** using BigQuery partitioning
- ✅ **Production-ready** for Looker Studio dashboards

---

## Project Objectives

### Business Goals
1. **Unified Analytics:** Consolidate data from 65 international stores
2. **Revenue Tracking:** Enable accurate revenue reporting in USD
3. **Customer Intelligence:** Track customer behavior and lifetime value
4. **Geographic Insights:** Analyze sales patterns by country/region
5. **Product Performance:** Identify best-selling products and categories

### Technical Goals
1. **Data Quality:** Implement comprehensive testing framework
2. **Scalability:** Design for growth to millions of transactions
3. **Maintainability:** Use dbt for version-controlled transformations
4. **Performance:** Optimize queries for real-time dashboard updates
5. **Documentation:** Create comprehensive technical documentation

---

## Technical Architecture

### Technology Stack
- **Cloud Platform:** Google Cloud Platform (GCP)
- **Data Warehouse:** BigQuery
- **Transformation:** dbt (data build tool) v1.8.9
- **Version Control:** Git
- **BI Tool:** Looker Studio
- **Language:** SQL (BigQuery dialect)

### Architecture Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                        DATA SOURCES                         │
├─────────────────────────────────────────────────────────────┤
│  MongoDB Events    │  IP Locations   │   Product Catalog   │
│  (35K events)      │  (3.2M records) │   (18.8K products)  │
└──────────┬──────────────────┬─────────────────┬────────────┘
           │                  │                 │
           ▼                  ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│                      STAGING LAYER                          │
│         (Views - Data Cleaning & Normalization)             │
├─────────────────────────────────────────────────────────────┤
│  stg_sales_orders  │  stg_ip_locations  │  stg_products   │
│  • UNNEST arrays   │  • Deduplicate      │  • Clean prices │
│  • Parse prices    │  • Generate keys    │  • Add unknown  │
│  • Normalize $     │                     │    member       │
└──────────┬──────────────────┬─────────────────┬────────────┘
           │                  │                 │
           ▼                  ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│                   DIMENSION LAYER                           │
│              (Tables - Reference Data)                      │
├─────────────────────────────────────────────────────────────┤
│ dim_date    │ dim_product │ dim_customer │ dim_store       │
│ dim_location│ dim_currency_rate                            │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                      FACT LAYER                             │
│           (Table - Transaction Metrics)                     │
├─────────────────────────────────────────────────────────────┤
│              fact_sales_order_tt                            │
│  • Line item grain (35K rows)                               │
│  • All metrics in USD                                       │
│  • Foreign keys to all dimensions                           │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                      MART LAYER                             │
│        (Table - Denormalized for Reporting)                 │
├─────────────────────────────────────────────────────────────┤
│              mart_sales_complete                            │
│  • Pre-joined dimensions (no JOINs in BI)                   │
│  • Calculated fields (AOV, customer metrics)                │
│  • Date partitioned for performance                         │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                   LOOKER STUDIO                             │
│              (Dashboards & Reports)                         │
└─────────────────────────────────────────────────────────────┘
```

### Dataset Organization
```
k20-de-2025 (BigQuery Project)
├── dbt_anthony_central1_staging      # 3 views
│   ├── stg_sales_orders
│   ├── stg_products
│   └── stg_ip_locations
│
├── dbt_anthony_central1_dimensions   # 6 tables
│   ├── dim_date
│   ├── dim_product
│   ├── dim_customer
│   ├── dim_store
│   ├── dim_location
│   └── dim_currency_rate
│
├── dbt_anthony_central1_facts        # 1 table
│   └── fact_sales_order_tt
│
└── dbt_anthony_central1_marts        # 1 table
    └── mart_sales_complete
```

---

## Data Sources & Quality

### Source 1: MongoDB Event Data
**Table:** `glamira_countly.summary_final_v6`

**Description:** E-commerce event tracking with checkout transactions

**Key Fields:**
- `order_id` - Unique order identifier
- `user_id_db` / `device_id` - Customer identifiers
- `cart_products` - Array of purchased items (requires UNNEST)
- `ip` - Customer IP address for geolocation
- `store_id` - Store identifier
- `time_stamp` - Transaction timestamp (Unix epoch)

**Volume:** 35,065 checkout_success events

**Data Quality Issues:**

| Issue | Count | Impact | Resolution |
|-------|-------|--------|-----------|
| Nested arrays | 100% | Requires UNNEST | Implemented in staging |
| Inconsistent price formats | 3 variations | Parse failures | Universal regex parser |
| 80+ currency variations | All records | Normalization needed | Comprehensive mapping |
| Zero-price items | 6,022 (17%) | Failed validation | Changed tests to >= 0 |

---

### Source 2: IP Location Data
**Table:** `glamira_countly.ip_locations`

**Description:** IP address to geographic location mapping

**Volume:** 3.2M+ IP records

**Coverage:** 54,579 unique locations used in transactions

**Completeness:**
- Country: 100%
- Region: 92%
- City: 87%

---

### Source 3: Product Catalog
**Table:** `glamira_project6.products_raw`

**Description:** Product information from web scraping

**Volume:** 18,820 products

**Critical Gap:**
- **966 orders (3.3%)** reference products NOT in catalog
- **Root Cause:** Products discontinued after crawl OR incomplete scraping
- **Business Decision:** Create "Unknown Product" member (product_id = -1)
- **Impact:** Revenue data preserved, product attributes unavailable for 3.3% of orders

---

## Implementation Journey

### Phase 1: Project Setup 

#### Initial Setup
```bash
# Create dbt project
dbt init k20_de_2025

# Configure BigQuery connection
# profiles.yml
k20_de_2025:
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: k20-de-2025
      dataset: dbt_anthony_central1
      location: us-central1
      threads: 4
```

#### Source Configuration
```yaml
# models/staging/sources.yml
sources:
  - name: glamira_countly
    database: k20-de-2025
    schema: glamira_countly
    tables:
      - name: summary_final_v6
      - name: ip_locations
  
  - name: glamira_project6
    database: k20-de-2025
    schema: glamira_project6
    tables:
      - name: products_raw
```

---

### Phase 2: Staging Layer 

#### Challenge 1: Nested Cart Data

**Problem:** Cart items stored as JSON array
```json
{
  "order_id": "1001",
  "cart_products": [
    {"product_id": "93297", "price": "€199,99", "amount": 1},
    {"product_id": "98784", "price": "€149,50", "amount": 2}
  ]
}
```

**Solution:** UNNEST operation
```sql
SELECT
    source.order_id,
    cart_item.product_id,
    cart_item.price,
    cart_item.amount AS quantity
FROM source
,UNNEST(cart_products) AS cart_item
WHERE source.collection = 'checkout_success'
```

**Outcome:** 26,031 orders → 35,064 line items

---

#### Challenge 2: Price Format Chaos

**Problem:** Three different regional formats
```
European:  "1.234,56"  (period as thousands, comma as decimal)
US/UK:     "1,234.56"  (comma as thousands, period as decimal)
Swiss:     "47'000"    (apostrophe as thousands separator)
```

**Failed Approach #1:** Simple CAST
```sql
CAST(price AS FLOAT64)  -- ❌ Fails on European format
```

**Failed Approach #2:** REPLACE comma with period
```sql
CAST(REPLACE(price, ',', '.') AS FLOAT64)  
-- ❌ Converts "1,234.56" → "1.234.56" (wrong!)
```

**Final Solution:** Regex-based format detection
```sql
CASE
    -- European format: ends with comma + 1-2 digits
    WHEN REGEXP_CONTAINS(price, r',\d{1,2}$') THEN
        SAFE_CAST(
            REPLACE(
                REGEXP_REPLACE(price, r"[^0-9,]", ''),  -- Remove everything except digits and comma
                ',', '.'  -- Replace comma with period
            ) AS FLOAT64
        )
    
    -- US/UK format: ends with period + 1-2 digits
    WHEN REGEXP_CONTAINS(price, r'\.\d{1,2}$') THEN
        SAFE_CAST(
            REGEXP_REPLACE(price, r"[^0-9.]", '')  -- Remove everything except digits and period
            AS FLOAT64
        )
    
    -- No clear decimal separator
    ELSE
        SAFE_CAST(
            REGEXP_REPLACE(price, r"[^0-9]", '')  -- Remove all non-digits
            AS FLOAT64
        )
END AS price_original
```

**Test Results:**
- ✅ European "1.234,56" → 1234.56
- ✅ US/UK "1,234.56" → 1234.56
- ✅ Swiss "CHF '47'000" → 47000
- ✅ Simple "199" → 199
- ✅ 100% parse success rate

---

#### Challenge 3: Currency Normalization Nightmare

**Problem:** 80+ currency variations found
```sql
-- Examples of variations for USD alone:
'$', '$US', 'US $', 'US$', 'USD', 'USD $', 'dolar', 'долл США'

-- Euro variations:
'EUR', '€', 'евро', 'يورو'

-- Swedish Krona:
'SEK', 'kr', 'шведских крон', '瑞典克朗', '، كرونة'
```

**Solution:** Comprehensive CASE statement (200+ lines)
```sql
CASE
    -- USD variations (8 variations)
    WHEN currency IN ('$', '$US', 'US $', 'US$', 'USD', 'USD $', 'dolar', 'долл США') 
        THEN 'USD'
    
    -- EUR variations (4 variations)
    WHEN currency IN ('EUR', '€', 'евро', 'يورو') 
        THEN 'EUR'
    
    -- GBP
    WHEN currency = '£' THEN 'GBP'
    
    -- ... 49 more currencies ...
    
    ELSE 'USD'  -- Default for unknown
END AS currency_code
```

**Outcome:** 80+ variations → 52 standard ISO codes

---

#### Challenge 4: Zero-Price Items

**Problem:** 6,022 transactions with price = 0 failing tests
```sql
-- Original filter
WHERE price_original > 0  -- ❌ Removes 6K valid orders

-- Test failure:
dbt_utils.expression_is_true: price_original > 0
Got 6022 results, configured to fail if != 0
```

**Investigation:**
```sql
SELECT price, COUNT(*) 
FROM unnested_cart 
WHERE price_cleaned = 0
GROUP BY price;

-- Results:
price    | count
---------|------
"0"      | 3,468
"Free"   | 2,554
```

**Root Cause:** Legitimate promotional/free items
- Free shipping
- Promotional gifts
- Samples
- Bundle discounts

**Decision:** Keep zero-price items
```sql
-- Updated filter
WHERE price_original >= 0  -- ✅ Allows free items

-- Updated tests
- dbt_utils.expression_is_true:
    expression: ">= 0"  # Changed from > 0
```

**Rationale:**
- Complete order history
- Track promotional campaigns
- Customer behavior insights
- Can filter with `WHERE price_usd > 0` in reports

**Impact:** Recovered all 35,064 transactions

---

### Phase 3: Dimension Layer 

#### Challenge 5: Missing Product References

**Problem:** 966 orders reference products not in catalog

**Investigation:**
```sql
-- Orders with missing products
SELECT 
    COUNT(DISTINCT o.order_id) AS orphaned_orders,
    COUNT(*) AS orphaned_line_items
FROM stg_sales_orders o
LEFT JOIN stg_products p ON o.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Results:
orphaned_orders: 966
orphaned_line_items: 1,053
percentage: 3.3%
```

**Attempted Solution #1:** Web scraping missing products
```python
# scripts/scrape_missing_products.py
import requests
from bs4 import BeautifulSoup

url = f"https://www.glamira.com/product-{product_id}.html"
response = requests.get(url)

# Result: 403 Forbidden (bot detection)
```

**Attempted Solution #2:** Selenium with headless Chrome
```python
# scripts/scrape_with_selenium.py
from selenium import webdriver

driver = webdriver.Chrome(options=chrome_options)
driver.get(url)
data = driver.execute_script("return window.react_data;")

# Result: Works but requires VM setup, decided not to pursue
```

**Final Solution:** Unknown Member Pattern
```sql
-- Add unknown member in stg_products
,unknown_member AS (
    SELECT 
        -1 AS product_id,
        'Unknown / Discontinued Product' AS product_name,
        'UNKNOWN' AS sku,
        0.0 AS min_price_original,
        0.0 AS max_price_original,
        'USD' AS price_currency
)

SELECT * FROM base_products
UNION ALL
SELECT * FROM unknown_member
```

**Fact Table Handling:**
```sql
-- Use COALESCE to map missing products to -1
,COALESCE(products.product_key, -1) AS product_key
```

**Test Configuration:**
```yaml
- name: product_key
  tests:
    - relationships:
        to: ref('dim_product')
        field: product_key
        config:
          severity: warn  # ✅ Expected 966 orphaned records
```

**Documentation in schema.yml:**
```yaml
description: |
  Foreign key to dim_product. 
  
  Note: ~966 orders (3.3%) map to product_key = -1 due to discontinued 
  products or incomplete catalog coverage. Revenue data is preserved but 
  product attributes are unavailable for these orders.
```

**Business Impact:**
- ✅ All revenue data preserved
- ✅ Known data quality documented
- ✅ Can filter with `WHERE product_key > 0` when product details needed
- ❌ 3.3% of orders lack product metadata

---

#### Challenge 6: Surrogate Key Generation

**Problem:** Natural keys are strings, need numeric keys for performance

**Solution:** Hash-based surrogate keys using dbt_utils
```sql
-- Generate 64-bit integer from MD5 hash
CAST(
    CONCAT('0x', SUBSTR(
        {{ dbt_utils.generate_surrogate_key(['product_id']) }}, 
        1, 15
    )) 
    AS INT64
) AS product_key
```

**Benefits:**
- Consistent key generation
- Numeric for better JOIN performance
- Deterministic (same input → same key)

---

### Phase 4: Fact Table 

#### Challenge 7: Transaction ID Confusion

**Problem:** Used `transaction_id` but field doesn't exist in staging

**Error:**
```
Database Error in model fact_sales_order_tt
Name transaction_id not found inside orders at [36:71]
```

**Investigation:**
- Staging has `mongo_id` (from MongoDB _id field)
- Previously used alias `transaction_id` but was removed
- Fact table still referenced old field name

**Solution:**
```sql
-- Before (failed)
{{ dbt_utils.generate_surrogate_key(['orders.transaction_id', 'orders.product_id']) }}

-- After (fixed)
{{ dbt_utils.generate_surrogate_key(['orders.mongo_id', 'orders.product_id']) }}
```

**Lesson:** Keep field names consistent across layers

---

#### Challenge 8: Currency Conversion

**Problem:** Need all prices in USD for consistent reporting

**Solution:** Join to currency rate dimension
```sql
-- Convert to USD
,CAST(
    orders.price_original * COALESCE(currency_rates.exchange_rate_to_usd, 1.0) 
    AS NUMERIC
) AS price_usd

,CAST(
    (orders.price_original * COALESCE(currency_rates.exchange_rate_to_usd, 1.0)) * orders.quantity 
    AS NUMERIC
) AS line_total_usd
```

**Seed File:** `seeds/currency_rates.csv`
```csv
currency_code,exchange_rate_to_usd
USD,1.0
EUR,1.09
GBP,1.27
CHF,1.12
...
```

**Test:**
```yaml
- name: currency_code
  tests:
    - relationships:
        to: ref('dim_currency_rate')
        field: currency_code
```

---

### Phase 5: Testing & Validation 

#### Challenge 9: YAML Configuration Errors

**Problem:** Duplicate source definitions causing compilation errors

**Error:**
```
dbt found two sources with the name "glamira_countly_summary_final_v6"
- source in models/staging/sources.yml
- source in models/staging/schema.yml
```

**Root Cause:** Sources defined in TWO files
```yaml
# models/staging/sources.yml
sources:
  - name: glamira_countly  # ✅ Correct location

# models/staging/schema.yml
sources:  # ❌ Duplicate!
  - name: glamira_countly
```

**Solution:** Centralize sources
```yaml
# models/staging/sources.yml
version: 2
sources:
  - name: glamira_countly
    # ...

# models/staging/schema.yml
version: 2
models:  # NO sources: section
  - name: stg_products
    # ...
```

**Additional Fix:** Missing `version: 2` declarations
```yaml
# Every schema.yml must start with:
version: 2
```

**Lesson:** 
- Sources belong in `sources.yml` ONLY
- Every schema.yml needs `version: 2` as first line
- dbt will tell you which file has duplicates

---

#### Challenge 10: Test Cascading Failures

**Problem:** One failed test causes 37 downstream SKIPs

**Error:**
```
Failure in test not_null_stg_products_product_id
  Got 1 result, configured to fail if != 0

SKIPPED: fact_sales_order_tt (depends on stg_products)
SKIPPED: dim_product (depends on stg_products)
SKIPPED: 37 downstream tests
```

**Root Cause:** NULL product_ids in source data
```sql
-- Source had bad data
SELECT COUNT(*) FROM products_raw WHERE product_id IS NULL;
-- Result: 2 rows
```

**Solution:** Filter at source
```sql
WITH source AS (
    SELECT * FROM {{ source('glamira_project6', 'products_raw') }}
    WHERE product_id IS NOT NULL  -- ✅ Filter bad source data
)
```

**Lesson:** Always validate and filter source data in staging layer

---

#### Challenge 11: Test Performance

**Problem:** 82 tests taking 2+ minutes to run

**Investigation:**
```bash
dbt test --select stg_sales_orders
# Individual test: 15-20 seconds each
# Full suite: 2 minutes 30 seconds
```

**Optimization:** Use dbt selectors
```bash
# Test specific model
dbt test --select stg_sales_orders

# Test specific layer
dbt test --select staging

# Test specific type
dbt test --select test_type:unique
```

**Result:** Development workflow improved, only run full suite in CI/CD

---

### Phase 6: Mart Layer & Documentation 

#### Challenge 12: Dataset Schema Organization

**Problem:** Models created in wrong BigQuery datasets

**Initial Config:**
```yaml
# dbt_project.yml (wrong - all in one dataset)
models:
  k20_de_2025:
    +materialized: table
    +schema: dbt_anthony_central1
```

**Result:** All tables in same dataset, no organization

**Solution:** Schema-based organization
```yaml
models:
  k20_de_2025:
    staging:
      +materialized: view
      +schema: staging
    
    dimensions:
      +materialized: table
      +schema: dimensions
    
    facts:
      +materialized: table
      +schema: facts
    
    marts:
      +materialized: table
      +schema: marts

seeds:
  k20_de_2025:
    +schema: staging
```

**Result:** Clean dataset organization
```
dbt_anthony_central1_staging
dbt_anthony_central1_dimensions
dbt_anthony_central1_facts
dbt_anthony_central1_marts
```

---

#### Challenge 13: Mart Table Design

**Problem:** How to structure mart for easy BI consumption?

**Options Considered:**

**Option A:** Multiple specialized marts
```sql
mart_revenue_summary.sql
mart_customer_metrics.sql
mart_product_performance.sql
```

- ❌ Requires multiple data sources in Looker
- ❌ Complex for business users
- ✅ Better performance for specific use cases

**Option B:** One Big Table (OBT)
```sql
mart_sales_complete.sql
```

- ✅ Single data source in Looker
- ✅ No JOINs needed in BI layer
- ✅ Simple for business users
- ❌ Larger table size

**Decision:** Option B (OBT) for this project size

**Implementation:**
```sql
-- Pre-join all dimensions
SELECT
    -- Fact metrics
    fact.line_total_usd,
    fact.quantity,
    
    -- Product dimensions (flattened)
    products.product_name,
    products.category,
    products.collection,
    
    -- Customer dimensions
    customers.first_order_date,
    customers.total_orders AS customer_lifetime_orders,
    
    -- Calculated fields
    CASE WHEN fact.order_date = customers.first_order_date 
         THEN TRUE ELSE FALSE 
    END AS is_first_order,
    
    -- All other dimensions...
FROM fact
LEFT JOIN products ON ...
LEFT JOIN customers ON ...
-- ... all dimensions
```

**Performance Optimization:**
```sql
{{ config(
    materialized = 'table',
    partition_by = {
        'field': 'order_date',
        'data_type': 'date',
        'granularity': 'day'
    }
) }}
```

**Result:**
- ✅ Single Looker data source
- ✅ Sub-second query performance
- ✅ 35,064 rows (manageable size)

---

## Major Challenges & Solutions

### Summary Table

| # | Challenge | Impact | Solution | Lesson Learned |
|---|-----------|--------|----------|----------------|
| 1 | Nested cart arrays | Cannot query line items | UNNEST operation | Always check for nested data structures |
| 2 | 3 price formats | Parse failures | Regex-based detection | Never assume data format consistency |
| 3 | 80+ currency variations | Normalization impossible | Comprehensive CASE mapping | Document data quality upfront |
| 4 | 6K zero-price items | Test failures | Changed tests to >= 0 | Understand business context before filtering |
| 5 | 966 missing products | Orphaned transactions | Unknown member pattern | Accept known data limitations |
| 6 | Duplicate YAML sources | Compilation errors | Centralize in sources.yml | One source of truth for sources |
| 7 | Field name changes | Query failures | Consistent naming convention | Maintain naming consistency |
| 8 | NULL source data | Cascading failures | Filter at source | Clean data at entry point |
| 9 | Wrong dataset schema | Disorganized structure | Schema configuration | Plan dataset organization upfront |
| 10 | Slow tests | 2+ minute wait | Selective testing | Use test selectors in development |

---

## Key Learnings

### Technical Skills Gained

#### 1. Advanced SQL Techniques
```sql
-- UNNEST for array processing
SELECT * FROM table, UNNEST(array_column) AS element

-- Regex for pattern matching
WHEN REGEXP_CONTAINS(field, r',\d{1,2}$') THEN ...

-- Window functions for customer metrics
ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY order_date) AS order_sequence

-- SAFE_CAST for error handling
SAFE_CAST(dirty_field AS FLOAT64)  -- Returns NULL instead of error
```

#### 2. dbt Best Practices
- **Staging layer:** Clean and normalize only, no business logic
- **Dimension layer:** Build slowly-changing dimensions
- **Fact layer:** Store metrics and foreign keys
- **Mart layer:** Denormalize for BI consumption
- **Testing:** 80% coverage on critical fields
- **Documentation:** Every model and field documented

#### 3. Data Modeling Principles
- **Star schema:** Fact table surrounded by dimensions
- **Surrogate keys:** Use hash-based keys for performance
- **Unknown members:** Handle missing reference data gracefully
- **Grain:** Define and document fact table grain
- **Slowly changing dimensions:** Track customer metrics over time

#### 4. BigQuery Optimization
```sql
-- Partitioning for time-based queries
partition_by = {
    'field': 'order_date',
    'data_type': 'date',
    'granularity': 'day'
}

-- Clustering for common filters
cluster_by = ['customer_country', 'product_category']

-- Table vs View decision
-- Views: Staging (always fresh)
-- Tables: Dimensions, Facts, Marts (pre-computed)
```

#### 5. Data Quality Framework
- **Not Null:** Critical fields must have values
- **Unique:** Primary keys must be unique
- **Relationships:** Foreign keys must exist in parent table
- **Accepted Values:** Constrain to known values
- **Custom Tests:** Business logic validation

---

### Process & Methodology Learnings

#### 1. Incremental Development

**What Worked:**
- Build layer by layer (staging → dimensions → facts)
- Test each model before moving forward
- Use `dbt run --select model_name` for fast iteration

**What Didn't Work:**
- Building entire data warehouse before testing
- Making multiple changes at once
- Skipping documentation until the end

#### 2. Data Quality Management

**Key Insights:**
- **Document known issues** instead of hiding them
- **Use test severity levels** (error vs warn)
- **Filter bad data at source** to prevent cascading failures
- **Communicate data limitations** to stakeholders

**Example Documentation:**
```yaml
- name: product_key
  description: |
    Foreign key to dim_product. 
    
    Known Issue: ~966 orders (3.3%) map to product_key = -1 due to 
    discontinued products or incomplete catalog coverage. Revenue data 
    is preserved but product attributes are unavailable.
  tests:
    - relationships:
        config:
          severity: warn  # Expected limitation
```

#### 3. Stakeholder Communication

**Lessons:**
- **Be transparent** about data limitations
- **Quantify impact** (3.3% of orders affected)
- **Explain trade-offs** (keep revenue vs lose product details)
- **Provide workarounds** (filter WHERE product_key > 0)

#### 4. Version Control Best Practices
```bash
# Meaningful commit messages
git commit -m "feat: add zero-price handling in staging"
git commit -m "fix: correct product_key join in fact table"
git commit -m "docs: document unknown product pattern"

# Feature branches for major changes
git checkout -b feature/add-marts-layer
git checkout -b fix/currency-normalization

# Never commit profiles.yml (credentials)
echo "profiles.yml" >> .gitignore
```

---

### Business Intelligence Learnings

#### 1. Understanding Business Context

**Critical Questions:**
- Why are there zero-price items? → Promotions (keep them!)
- Why missing products? → Discontinued (document it!)
- Why multiple currencies? → International business (normalize!)
- What grain for fact table? → Line item (business needs detail)

#### 2. Balancing Completeness vs Quality

**Trade-off Example:**
```
Option A: Exclude 966 orphaned orders (3.3%)
  ✅ 100% data quality
  ❌ Lost revenue data
  ❌ Inaccurate totals

Option B: Keep orphaned orders, mark as "Unknown Product"
  ✅ Complete revenue data
  ✅ Documented limitation
  ❌ 3.3% missing product attributes
  
Decision: Option B (business preferred completeness)
```

#### 3. Performance vs Usability

**Mart Design Decision:**
```
Multiple Marts:
  ✅ Better query performance
  ✅ Smaller tables
  ❌ Complex for business users
  ❌ Multiple data sources in Looker

One Big Table:
  ✅ Single data source
  ✅ No JOINs in BI
  ✅ Drag-and-drop simplicity
  ❌ Slightly larger table

Decision: OBT (35K rows is manageable, usability > micro-optimization)
```

---

## Project Outcomes

### Quantitative Results

#### Data Warehouse Metrics

| Metric | Value | Details |
|--------|-------|---------|
| **Total Transactions** | 35,064 | Line item level |
| **Unique Orders** | 26,031 | Distinct order_ids |
| **Products** | 18,820 | Active catalog |
| **Customers** | 15,100 | Unique users |
| **Stores** | 65 | International presence |
| **Countries** | 150+ | Global customer base |
| **Date Range** | 2019-2029 | 4,017   |
| **Currencies Normalized** | 52 | From 80+ variations |

#### Data Quality Metrics

| Metric | Result | Target |
|--------|--------|--------|
| **Test Coverage** | 82 tests | 70+ |
| **Test Pass Rate** | 98.8% (81/82) | 95%+ |
| **Known Warnings** | 1 (documented) | <5 |
| **Data Completeness** | 96.7% | 95%+ |
| **Zero-Price Items** | 17.2% (kept intentionally) | N/A |
| **Price Parse Success** | 100% | 100% |
| **Currency Normalization** | 100% | 100% |

#### Performance Metrics

| Metric | Value | Target |
|--------|-------|--------|
| **Full Rebuild Time** | 12-16 seconds | <30s |
| **Test Execution Time** | 40-45 seconds | <60s |
| **Mart Query Time** | <1 second | <2s |
| **Dashboard Load Time** | 2-3 seconds | <5s |

---

### Qualitative Outcomes

#### 1. Production-Ready Data Warehouse

✅ **Scalable Architecture**
- Handles 35K+ transactions efficiently
- Can scale to millions with same structure
- Partitioned tables for time-based queries

✅ **Maintainable Codebase**
- Version controlled with Git
- Comprehensive documentation
- Modular design (easy to modify)

✅ **Reliable Data Quality**
- 82 automated tests
- Known issues documented
- Data validation at every layer

#### 2. Business Value Delivered

✅ **Unified Analytics Platform**
- Single source of truth for sales data
- Consistent metrics across all reports
- Real-time data access (views on source)

✅ **Multi-Currency Support**
- All revenue in USD for comparison
- Supports 52 currencies
- Easy to add new currencies

✅ **Customer Intelligence**
- Track lifetime value
- Identify first-time vs repeat customers
- Analyze cohorts and retention

✅ **Geographic Insights**
- Sales by country/region/city
- Store performance comparison
- Market penetration analysis

#### 3. Technical Excellence

✅ **Modern Data Stack**
- dbt for transformations (industry standard)
- BigQuery for warehousing (scalable)
- Looker Studio for visualization (accessible)

✅ **Best Practices Applied**
- Dimensional modeling (Kimball methodology)
- Staging → Dimensions → Facts → Marts
- Comprehensive testing framework
- Documentation as code

✅ **Knowledge Transfer**
- Detailed README
- Inline SQL comments
- dbt docs (run `dbt docs serve`)
- Sample queries provided

---

### Deliverables

#### 1. Data Warehouse
- ✅ 11 models (3 staging, 6 dimensions, 1 fact, 1 mart)
- ✅ 82 data quality tests
- ✅ 1 seed file (currency rates)
- ✅ Full documentation

#### 2. Code Repository
```
k20_de_2025/
├── README.md (this file)
├── dbt_project.yml
├── models/
│   ├── staging/ (3 models + tests)
│   ├── dimensions/ (6 models + tests)
│   ├── facts/ (1 model + tests)
│   └── marts/ (1 model)
├── seeds/
│   └── currency_rates.csv
└── tests/
    └── (custom tests)
```

#### 3. Documentation
- ✅ Architecture diagrams
- ✅ Data dictionary (via dbt docs)
- ✅ Known issues documented
- ✅ Query examples
- ✅ Looker setup guide

#### 4. Business Intelligence
- ✅ Mart table ready for Looker
- ✅ Sample dashboard queries
- ✅ KPI definitions
- ✅ Filter recommendations

---

## Testing Framework

### Overview

**Total Coverage:** 82 data quality tests across all layers  
**Test Success Rate:** 98.8% (81 PASS, 1 WARN, 0 ERROR)  
**Test Definitions:** All tests are defined in `schema.yml` files within each model directory

### Test Distribution
```
models/
├── staging/schema.yml           # 24 tests - Data cleaning validation
├── dimensions/schema.yml        # 36 tests - Reference data integrity  
├── facts/schema.yml             # 21 tests - Transaction metrics validation
└── marts/schema.yml             # 1 test  - Known data limitation (WARNING)
```

### What We Test

#### 1. **Data Integrity (40 tests)**
- **Not Null:** Critical fields must have values (31 tests)
- **Unique:** Primary keys are unique (9 tests)

**Purpose:** Ensure no missing data in key fields

**Example:**
```yaml
- name: product_id
  tests:
    - not_null    # No missing product IDs
    - unique      # No duplicate products
```

---

#### 2. **Referential Integrity (7 tests)**
- **Relationships:** Foreign keys exist in parent tables

**Purpose:** Ensure JOINs won't create orphaned records (except documented cases)

**Example:**
```yaml
- name: date_key
  tests:
    - relationships:
        to: ref('dim_date')
        field: date_key
```

**Special Case - Known Warning:**
```yaml
- name: product_key
  tests:
    - relationships:
        to: ref('dim_product')
        field: product_key
        config:
          severity: warn  # 966 orders (3.3%) have discontinued products
```

---

#### 3. **Business Rules (32 tests)**
- **Expression Validation:** Custom logic using dbt_utils

**Purpose:** Enforce business constraints on data values

**Examples:**
```yaml
# Prices can be zero (free items allowed)
- name: price_original
  tests:
    - dbt_utils.expression_is_true:
        expression: ">= 0"

# Quantities must be positive
- name: quantity
  tests:
    - dbt_utils.expression_is_true:
        expression: "> 0"
```

---

#### 4. **Data Quality Constraints (3 tests)**
- **Accepted Values:** Restrict to known valid values

**Purpose:** Catch data entry errors or invalid codes

**Example:**
```yaml
- name: price_currency
  tests:
    - accepted_values:
        values: ['EUR', 'USD', 'BGN', 'GBP', 'TRY', 'PLN']
```

---

### Running Tests
```bash
# Run all 82 tests
dbt test

# Expected output:
# PASS=81 WARN=1 ERROR=0 SKIP=0 TOTAL=82

# Run tests for specific model
dbt test --select stg_sales_orders

# Run tests for specific layer
dbt test --select staging        # 24 tests
dbt test --select dimensions     # 36 tests
dbt test --select facts          # 21 tests
```

---

### The One Warning (Expected)

**Warning:** `relationships_fact_sales_order_tt_product_key__product_key__ref_dim_product_`

**What it means:**
- 966 orders (3.3%) reference products not in catalog
- Products were discontinued after original scraping
- **Business Decision:** Keep revenue data, accept missing product attributes

**Impact:**
- ✅ All revenue data preserved
- ❌ 3.3% of orders lack product details (category, name, etc.)

**Workaround:**
```sql
-- Filter out unknown products when product attributes needed
WHERE product_key > 0
```

**Why it's a warning (not error):**
- Documented limitation
- Business prefers complete revenue over perfect product coverage
- Users can filter when needed

---

### Test Files Location

All test definitions are in the repository:
```
models/
├── staging/
│   ├── schema.yml              # ← Tests for stg_* models
│   └── sources.yml             # ← Source definitions
├── dimensions/
│   └── schema.yml              # ← Tests for dim_* models
├── facts/
│   └── schema.yml              # ← Tests for fact_* models
└── marts/
    └── schema.yml              # ← Tests for mart_* models
```

**View test definitions:** Open any `schema.yml` file to see complete test configurations

---

### Key Takeaways

✅ **Comprehensive Coverage:** Every critical field tested  
✅ **Automated Validation:** Tests run on every dbt build  
✅ **Known Issues Documented:** 1 expected warning with business context  
✅ **Production Ready:** 98.8% pass rate ensures data quality  


**Philosophy:** Tests protect data quality while documenting known limitations transparently.

---
## Data Model Documentation

### Entity Relationship Diagram
```
┌─────────────┐
│  dim_date   │
│─────────────│
│ date_key PK │
│ date_day    │
│ year        │
│ quarter     │
│ month       │
│ day_name    │
│ is_weekend  │
└──────┬──────┘
       │
       │
┌──────┴────────┐
│ dim_product   │
│───────────────│
│ product_key PK│
│ product_id    │
│ product_name  │
│ category      │
│ collection    │
│ gender        │
│ min_price     │
│ max_price     │
└──────┬────────┘
       │
       │                    ┌─────────────────┐
       │                    │ dim_currency_   │
       │                    │     rate        │
       │                    │─────────────────│
       │                    │ currency_code PK│
       │                    │ exchange_rate_  │
       │                    │   to_usd        │
       │                    └────────┬────────┘
       │                             │
       │         ┌───────────────────┴─────────────────┐
       │         │                                       │
┌──────┴─────────▼─────────────────────────────────────▼───┐
│              fact_sales_order_tt                          │
│───────────────────────────────────────────────────────────│
│ sales_order_item_key PK                                   │
│ date_key FK                                               │
│ product_key FK                                            │
│ user_id FK                                                │
│ store_id FK                                               │
│ location_key FK                                           │
│ currency_code FK                                          │
│ order_id                                                  │
│ quantity                                                  │
│ price_original                                            │
│ price_usd                                                 │
│ line_total_usd                                            │
│ is_paypal                                                 │
└───────────────────┬───────────────────────────────────────┘
                    │
        ┌───────────┴───────────────────────┬──────────┐
        │                                   │          │
┌───────▼────────┐  ┌─────────────────┐  ┌─▼──────────▼──┐
│dim_location    │  │ dim_customer    │  │  dim_store    │
│────────────────│  │─────────────────│  │───────────────│
│location_key PK │  │ user_id PK      │  │ store_id PK   │
│country_name    │  │ email           │  │ store_name    │
│region_name     │  │ first_order_    │  │ store_domain  │
│city_name       │  │   date          │  │ country       │
└────────────────┘  │ total_orders    │  └───────────────┘
                    └─────────────────┘

```

### Grain Definition

**Fact Table Grain:** One row per product per order (line item level)

**Example:**
```
Order #1001 contains:
  - 1x Gold Ring ($500)
  - 2x Silver Earrings ($200 each)
  
Fact table will have 2 rows:
  Row 1: order_id=1001, product=Ring, quantity=1, line_total=$500
  Row 2: order_id=1001, product=Earrings, quantity=2, line_total=$400
```

**Why Line Item Grain?**
- ✅ Detailed product analysis
- ✅ Accurate quantity tracking
- ✅ Support for basket analysis
- ✅ Revenue attribution to products

---

## Query Examples

### Revenue Analysis

#### Total Revenue (Excluding Free Items)
```sql
SELECT 
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(line_total_usd) AS total_revenue_usd,
    SUM(line_total_usd) / COUNT(DISTINCT order_id) AS avg_order_value,
    SUM(quantity) AS total_units_sold
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
WHERE price_usd > 0;  -- Exclude promotional/free items
```

#### Revenue by Month
```sql
SELECT 
    order_year,
    order_month,
    order_month_name,
    COUNT(DISTINCT order_id) AS orders,
    SUM(line_total_usd) AS revenue,
    SUM(line_total_usd) / COUNT(DISTINCT order_id) AS aov
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
WHERE price_usd > 0
GROUP BY order_year, order_month, order_month_name
ORDER BY order_year, order_month;
```

#### Revenue by Quarter with YoY Growth
```sql
WITH quarterly_revenue AS (
    SELECT 
        order_year,
        order_quarter,
        SUM(line_total_usd) AS revenue
    FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
    WHERE price_usd > 0
    GROUP BY order_year, order_quarter
)
SELECT 
    order_year,
    order_quarter,
    revenue,
    LAG(revenue) OVER (PARTITION BY order_quarter ORDER BY order_year) AS prev_year_revenue,
    ROUND((revenue - LAG(revenue) OVER (PARTITION BY order_quarter ORDER BY order_year)) / 
          LAG(revenue) OVER (PARTITION BY order_quarter ORDER BY order_year) * 100, 2) AS yoy_growth_pct
FROM quarterly_revenue
ORDER BY order_year, order_quarter;
```

---

### Product Analysis

#### Top 20 Products by Revenue
```sql
SELECT 
    product_name,
    category,
    collection,
    COUNT(DISTINCT order_id) AS orders,
    SUM(quantity) AS units_sold,
    SUM(line_total_usd) AS revenue,
    ROUND(SUM(line_total_usd) / SUM(quantity), 2) AS avg_unit_price
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
WHERE price_usd > 0 
  AND is_unknown_product = FALSE
GROUP BY product_name, category, collection
ORDER BY revenue DESC
LIMIT 20;
```

#### Product Category Performance
```sql
SELECT 
    category,
    COUNT(DISTINCT product_id) AS products_in_category,
    COUNT(DISTINCT order_id) AS orders,
    SUM(quantity) AS units_sold,
    SUM(line_total_usd) AS revenue,
    ROUND(AVG(line_total_usd), 2) AS avg_transaction_value
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
WHERE price_usd > 0 
  AND is_unknown_product = FALSE
GROUP BY category
ORDER BY revenue DESC;
```

---

### Customer Analysis

#### New vs Returning Customers
```sql
SELECT 
    CASE WHEN is_first_order THEN 'New Customer' ELSE 'Returning Customer' END AS customer_type,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT user_id) AS customers,
    SUM(line_total_usd) AS revenue,
    ROUND(SUM(line_total_usd) / COUNT(DISTINCT order_id), 2) AS aov
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
WHERE price_usd > 0
GROUP BY customer_type;
```

#### Customer Lifetime Value (Top 50)
```sql
SELECT 
    user_id,
    customer_first_order_date,
    customer_lifetime_orders,
    COUNT(DISTINCT order_id) AS orders_in_dataset,
    SUM(line_total_usd) AS total_revenue,
    ROUND(SUM(line_total_usd) / COUNT(DISTINCT order_id), 2) AS avg_order_value,
    MIN(order_date) AS first_order,
    MAX(order_date) AS last_order,
    DATE_DIFF(MAX(order_date), MIN(order_date), DAY) AS customer_lifespan_days
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
WHERE price_usd > 0
GROUP BY user_id, customer_first_order_date, customer_lifetime_orders
ORDER BY total_revenue DESC
LIMIT 50;
```

---

### Geographic Analysis

#### Revenue by Country (Top 20)
```sql
SELECT 
    customer_country,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT user_id) AS customers,
    SUM(line_total_usd) AS revenue,
    ROUND(SUM(line_total_usd) / COUNT(DISTINCT order_id), 2) AS aov,
    ROUND(SUM(line_total_usd) * 100.0 / SUM(SUM(line_total_usd)) OVER (), 2) AS revenue_share_pct
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
WHERE price_usd > 0
GROUP BY customer_country
ORDER BY revenue DESC
LIMIT 20;
```

#### Store Performance Comparison
```sql
SELECT 
    store_country,
    store_name,
    COUNT(DISTINCT order_id) AS orders,
    SUM(line_total_usd) AS revenue,
    ROUND(SUM(line_total_usd) / COUNT(DISTINCT order_id), 2) AS aov,
    COUNT(DISTINCT user_id) AS unique_customers
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
WHERE price_usd > 0
GROUP BY store_country, store_name
ORDER BY revenue DESC;
```

---

### Data Quality Analysis

#### Orders with Unknown Products
```sql
SELECT 
    COUNT(DISTINCT order_id) AS orders_with_unknown_products,
    SUM(line_total_usd) AS revenue_from_unknown_products,
    ROUND(COUNT(DISTINCT order_id) * 100.0 / (
        SELECT COUNT(DISTINCT order_id) 
        FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
    ), 2) AS pct_of_total_orders
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
WHERE is_unknown_product = TRUE;

-- Expected: ~966 orders (3.3%)
```

#### Free/Promotional Items Analysis
```sql
SELECT 
    'Paid Items' AS item_type,
    COUNT(*) AS line_items,
    SUM(line_total_usd) AS revenue
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
WHERE is_free_item = FALSE

UNION ALL

SELECT 
    'Free Items' AS item_type,
    COUNT(*) AS line_items,
    0 AS revenue
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
WHERE is_free_item = TRUE;

-- Expected: ~6,022 free items (17.2%)
```

---

### Basket Analysis

#### Average Items Per Order
```sql
SELECT 
    COUNT(*) AS total_line_items,
    COUNT(DISTINCT order_id) AS distinct_orders,
    ROUND(COUNT(*) / COUNT(DISTINCT order_id), 2) AS avg_items_per_order,
    MAX(items_per_order) AS max_items_in_single_order
FROM (
    SELECT 
        order_id,
        COUNT(*) AS items_per_order
    FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
    GROUP BY order_id
);

-- Expected: ~1.35 items per order
```

---

## Dashboard Setup Guide

### Looker Studio Connection

#### Step 1: Create Data Source
1. Navigate to https://lookerstudio.google.com
2. Click **Create** → **Data Source**
3. Select **BigQuery** connector
4. Authorize with your Google account
5. Navigate to:
   - **Project:** `k20-de-2025`
   - **Dataset:** `dbt_anthony_central1_marts`
   - **Table:** `mart_sales_complete`
6. Click **Connect**

#### Step 2: Configure Fields

Looker Studio will auto-detect field types. Verify/update these:

**Dimensions:**
- `order_date` → Date
- `order_year` → Number → Year
- `order_quarter` → Number
- `order_month_name` → Text
- `customer_country` → Text → Geo → Country
- `customer_city` → Text → Geo → City
- `product_name` → Text
- `category` → Text
- `is_first_order` → Boolean
- `is_free_item` → Boolean

**Metrics:**
- `line_total_usd` → Currency (USD) → Aggregation: SUM
- `quantity` → Number → Aggregation: SUM
- `price_usd` → Currency (USD) → Aggregation: AVG

#### Step 3: Create Calculated Fields

**Total Revenue:**
```
SUM(line_total_usd)
```

**Total Orders:**
```
COUNT_DISTINCT(order_id)
```

**Average Order Value:**
```
SUM(line_total_usd) / COUNT_DISTINCT(order_id)
```

**Total Units Sold:**
```
SUM(quantity)
```

---

### Dashboard 1: Revenue Overview

**Layout:**
```
┌─────────────────────────────────────────────────────┐
│  Revenue Overview Dashboard                         │
├─────────────┬─────────────┬─────────────────────────┤
│ Total       │ Total       │ Avg Order               │
│ Revenue     │ Orders      │ Value                   │
│ $10.5M      │ 24,031      │ $437                    │
├─────────────────────────────────────────────────────┤
│                                                      │
│   Revenue Trend (Line Chart - Monthly)              │
│                                                      │
├───────────────────────┬─────────────────────────────┤
│ Top 10 Products       │ Revenue by Country (Map)    │
│ (Bar Chart)           │                             │
│                       │                             │
├───────────────────────┴─────────────────────────────┤
│                                                      │
│   Product Performance Table                         │
│   (product, category, orders, revenue)              │
│                                                      │
└─────────────────────────────────────────────────────┘

```

- link to the report **https://lookerstudio.google.com/s/oFI8wInlCtY**


**Charts to Add:**

1. **Scorecard: Total Revenue**
   - Metric: `SUM(line_total_usd)`
   - Filter: `price_usd > 0`
   - Format: Currency ($)
   - Comparison: Previous period

2. **Scorecard: Total Orders**
   - Metric: `COUNT_DISTINCT(order_id)`
   - Filter: `price_usd > 0`

3. **Scorecard: Average Order Value**
   - Calculated field: `SUM(line_total_usd) / COUNT_DISTINCT(order_id)`
   - Filter: `price_usd > 0`

4. **Time Series: Revenue Trend**
   - Date dimension: `order_date`
   - Metric: `SUM(line_total_usd)`
   - Filter: `price_usd > 0`
   - Style: Line chart, smooth lines
   - Date range control: Yes

5. **Bar Chart: Top 10 Products**
   - Dimension: `product_name`
   - Metric: `SUM(line_total_usd)`
   - Sort: Descending
   - Rows: 10
   - Filter: `price_usd > 0` AND `is_unknown_product = FALSE`

6. **Geo Chart: Revenue by Country**
   - Geo dimension: `customer_country`
   - Metric: `SUM(line_total_usd)`
   - Filter: `price_usd > 0`

7. **Table: Product Performance**
   - Dimensions: `product_name`, `category`, `collection`
   - Metrics:
     - Orders: `COUNT_DISTINCT(order_id)`
     - Revenue: `SUM(line_total_usd)`
     - Units: `SUM(quantity)`
   - Sort: Revenue DESC
   - Rows: 20
   - Filter: `price_usd > 0` AND `is_unknown_product = FALSE`

**Filters to Add:**
- Date range control (default: Last 12 months)
- Category dropdown
- Country dropdown

---

## Maintenance & Operations

### Daily Operations

#### Data Freshness
```bash
# Check when data was last updated
SELECT MAX(event_ts) AS last_transaction
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`;
```

#### Quick Health Check
```bash
# Run all tests
dbt test

# Expected result:
# PASS=81 WARN=1 ERROR=0
```

---

### Weekly Maintenance

#### 1. Run Full Rebuild
```bash
# Refresh all models
dbt run --full-refresh

# Run tests
dbt test

# Generate documentation
dbt docs generate
```

#### 2. Data Quality Monitoring
```sql
-- Check for new unknown products
SELECT 
    COUNT(DISTINCT order_id) AS unknown_product_orders,
    ROUND(COUNT(DISTINCT order_id) * 100.0 / (
        SELECT COUNT(DISTINCT order_id) 
        FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
    ), 2) AS pct
FROM `k20-de-2025.dbt_anthony_central1_marts.mart_sales_complete`
WHERE is_unknown_product = TRUE;

-- Should stay around 3.3%
```

---

### Common dbt Commands
```bash
# Installation
pip install dbt-bigquery

# Initialize project
dbt init project_name

# Run models
dbt run                              # Run all models
dbt run --select model_name          # Run specific model
dbt run --select model_name+         # Run model + downstream
dbt run --select +model_name         # Run model + upstream
dbt run --select staging.*           # Run all in folder
dbt run --full-refresh               # Drop and recreate

# Run tests
dbt test                             # Run all tests
dbt test --select model_name         # Test specific model
dbt test --select test_type:unique   # Run specific test type

# Seeds
dbt seed                             # Load all seeds
dbt seed --full-refresh              # Reload seeds
dbt seed --select seed_name          # Load specific seed

# Documentation
dbt docs generate                    # Generate docs
dbt docs serve                       # View docs locally

# Debug
dbt compile                          # Compile SQL
dbt debug                            # Test connection

# Build (run + test + seed)
dbt build                            # Everything
dbt build --select model_name+       # Model + downstream + tests
```

---

### B. Resources & References

#### Documentation
- [dbt Documentation](https://docs.getdbt.com/)
- [BigQuery Documentation](https://cloud.google.com/bigquery/docs)
- [Looker Studio Help](https://support.google.com/looker-studio)

#### Learning Resources
- [dbt Learn](https://courses.getdbt.com/)
- [Kimball Dimensional Modeling](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/)
- [BigQuery Best Practices](https://cloud.google.com/bigquery/docs/best-practices)


---


