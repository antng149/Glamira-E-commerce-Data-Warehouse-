---

## Tóm Tắt Dự Án

Dự án này xây dựng một kho dữ liệu (data warehouse) production-ready cho Glamira, một công ty thương mại điện tử trang sức quốc tế. Kho dữ liệu tổng hợp dữ liệu giao dịch từ 65 cửa hàng trên nhiều quốc gia, xử lý hơn 35,000 giao dịch, và hỗ trợ phân tích kinh doanh thông qua mô hình dữ liệu chiều (dimensional modeling) và bảng marts.

### Thành Tựu Chính
- ✅ **35,064 giao dịch** được xử lý từ dữ liệu MongoDB thô
- ✅ **52 loại tiền tệ** được chuẩn hóa sang USD cho báo cáo nhất quán
- ✅ **82 kiểm tra chất lượng dữ liệu** với tỷ lệ đạt 99%
- ✅ **Kiến trúc 4 tầng** (staging → dimensions → facts → marts)
- ✅ **Hiệu suất truy vấn dưới 1 giây** sử dụng phân vùng BigQuery
- ✅ **Sẵn sàng production** cho dashboard Looker Studio

---

## Mục Tiêu Dự Án

### Mục Tiêu Kinh Doanh
1. **Phân tích thống nhất:** Tổng hợp dữ liệu từ 65 cửa hàng quốc tế
2. **Theo dõi doanh thu:** Báo cáo doanh thu chính xác bằng USD
3. **Thông tin khách hàng:** Theo dõi hành vi và giá trị vòng đời khách hàng
4. **Phân tích địa lý:** Phân tích xu hướng bán hàng theo quốc gia/khu vực
5. **Hiệu suất sản phẩm:** Xác định sản phẩm bán chạy và danh mục

### Mục Tiêu Kỹ Thuật
1. **Chất lượng dữ liệu:** Triển khai framework kiểm tra toàn diện
2. **Khả năng mở rộng:** Thiết kế để phát triển đến hàng triệu giao dịch
3. **Dễ bảo trì:** Sử dụng dbt cho transformations có version control
4. **Hiệu suất:** Tối ưu hóa truy vấn cho cập nhật dashboard real-time
5. **Tài liệu:** Tạo tài liệu kỹ thuật toàn diện

---

## Kiến Trúc Kỹ Thuật

### Công Nghệ Sử Dụng
- **Nền tảng Cloud:** Google Cloud Platform (GCP)
- **Data Warehouse:** BigQuery
- **Transformation:** dbt (data build tool) v1.8.9
- **Version Control:** Git
- **Công cụ BI:** Looker Studio
- **Ngôn ngữ:** SQL (BigQuery dialect)

### Kiến Trúc Hệ Thống
```
┌─────────────────────────────────────────────────────────────┐
│                     NGUỒN DỮ LIỆU                          │
├─────────────────────────────────────────────────────────────┤
│  MongoDB Events    │  IP Locations   │   Product Catalog   │
│  (35K events)      │  (3.2M records) │   (18.8K products)  │
└──────────┬──────────────────┬─────────────────┬────────────┘
           │                  │                 │
           ▼                  ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│                    TẦNG STAGING                             │
│         (Views - Làm sạch & Chuẩn hóa dữ liệu)             │
├─────────────────────────────────────────────────────────────┤
│  stg_sales_orders  │  stg_ip_locations  │  stg_products   │
│  • UNNEST arrays   │  • Loại trùng       │  • Làm sạch giá │
│  • Parse giá       │  • Tạo keys         │  • Thêm unknown │
│  • Chuẩn hóa $     │                     │    member       │
└──────────┬──────────────────┬─────────────────┬────────────┘
           │                  │                 │
           ▼                  ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│                   TẦNG DIMENSION                            │
│              (Tables - Dữ liệu tham chiếu)                  │
├─────────────────────────────────────────────────────────────┤
│ dim_date    │ dim_product │ dim_customer │ dim_store       │
│ dim_location│ dim_currency_rate                            │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                      TẦNG FACT                              │
│           (Table - Metrics giao dịch)                       │
├─────────────────────────────────────────────────────────────┤
│              fact_sales_order_tt                            │
│  • Grain: line item (35K rows)                              │
│  • Tất cả metrics tính bằng USD                             │
│  • Foreign keys đến tất cả dimensions                       │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                      TẦNG MART                              │
│        (Table - Denormalized cho Reporting)                 │
├─────────────────────────────────────────────────────────────┤
│              mart_sales_complete                            │
│  • Pre-joined dimensions (không cần JOIN trong BI)         │
│  • Calculated fields (AOV, customer metrics)                │
│  • Phân vùng theo date để tối ưu hiệu suất                 │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                   LOOKER STUDIO                             │
│              (Dashboards & Reports)                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Các Thách Thức Chính & Giải Pháp

### Tóm Tắt 10 Thách Thức Lớn

| # | Thách thức | Tác động | Giải pháp | Bài học |
|---|-----------|----------|-----------|---------|
| 1 | Nested cart arrays | Không thể query line items | Sử dụng UNNEST | Luôn kiểm tra nested structures |
| 2 | 3 định dạng giá khác nhau | Parse bị lỗi | Regex-based detection | Đừng giả định format nhất quán |
| 3 | 80+ biến thể tiền tệ | Không thể chuẩn hóa | CASE statement toàn diện | Document chất lượng dữ liệu sớm |
| 4 | 6K items giá = 0 | Test thất bại | Đổi tests thành >= 0 | Hiểu context kinh doanh trước khi filter |
| 5 | 966 sản phẩm thiếu | Transactions mồ côi | Unknown member pattern | Chấp nhận giới hạn dữ liệu đã biết |
| 6 | Trùng YAML sources | Lỗi compilation | Tập trung vào sources.yml | Một source of truth cho sources |
| 7 | Đổi tên fields | Query bị lỗi | Convention đặt tên nhất quán | Duy trì consistency |
| 8 | NULL ở source data | Lỗi cascade | Filter tại source | Làm sạch dữ liệu tại điểm vào |
| 9 | Sai dataset schema | Cấu trúc lộn xộn | Cấu hình schema | Lên kế hoạch tổ chức dataset trước |
| 10 | Tests chậm | Chờ 2+ phút | Selective testing | Dùng test selectors khi dev |

---

## Những Thách Thức Chi Tiết

### Challenge 1: Nested Cart Data (Dữ liệu giỏ hàng lồng nhau)

**Vấn đề:** Cart items được lưu dạng JSON array
```json
{
  "order_id": "1001",
  "cart_products": [
    {"product_id": "93297", "price": "€199,99", "amount": 1},
    {"product_id": "98784", "price": "€149,50", "amount": 2}
  ]
}
```

**Giải pháp:** Sử dụng UNNEST
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

**Kết quả:** 26,031 orders → 35,064 line items

---

### Challenge 2: Price Format Chaos (Hỗn loạn định dạng giá)

**Vấn đề:** 3 định dạng khu vực khác nhau
```
Châu Âu:  "1.234,56"  (dấu chấm = thousands, dấu phẩy = decimal)
Mỹ/Anh:   "1,234.56"  (dấu phẩy = thousands, dấu chấm = decimal)
Thụy Sĩ:  "47'000"    (dấu nháy = thousands separator)
```

**Giải pháp:** Regex-based format detection
```sql
CASE
    -- Format Châu Âu: kết thúc bằng dấu phẩy + 1-2 chữ số
    WHEN REGEXP_CONTAINS(price, r',\d{1,2}$') THEN
        SAFE_CAST(
            REPLACE(
                REGEXP_REPLACE(price, r"[^0-9,]", ''),
                ',', '.'
            ) AS FLOAT64
        )
    
    -- Format Mỹ/Anh: kết thúc bằng dấu chấm + 1-2 chữ số
    WHEN REGEXP_CONTAINS(price, r'\.\d{1,2}$') THEN
        SAFE_CAST(
            REGEXP_REPLACE(price, r"[^0-9.]", '')
            AS FLOAT64
        )
    
    -- Không có decimal rõ ràng
    ELSE
        SAFE_CAST(
            REGEXP_REPLACE(price, r"[^0-9]", '')
            AS FLOAT64
        )
END AS price_original
```

**Kết quả kiểm tra:**
- ✅ Châu Âu "1.234,56" → 1234.56
- ✅ Mỹ/Anh "1,234.56" → 1234.56
- ✅ Thụy Sĩ "CHF '47'000" → 47000
- ✅ Đơn giản "199" → 199
- ✅ 100% parse thành công

---

### Challenge 3: Currency Normalization (Chuẩn hóa tiền tệ)

**Vấn đề:** Tìm thấy 80+ biến thể tiền tệ
```sql
-- Ví dụ các biến thể của USD:
'$', '$US', 'US $', 'US$', 'USD', 'USD $', 'dolar', 'долл США'

-- Biến thể Euro:
'EUR', '€', 'евро', 'يورو'

-- Swedish Krona:
'SEK', 'kr', 'шведских крон', '瑞典克朗', '، كرونة'
```

**Giải pháp:** CASE statement toàn diện (200+ dòng)
```sql
CASE
    -- Biến thể USD (8 variations)
    WHEN currency IN ('$', '$US', 'US $', 'US$', 'USD', 'USD $', 'dolar', 'долл США') 
        THEN 'USD'
    
    -- Biến thể EUR (4 variations)
    WHEN currency IN ('EUR', '€', 'евро', 'يورو') 
        THEN 'EUR'
    
    -- ... 49 loại tiền tệ khác ...
    
    ELSE 'USD'  -- Mặc định cho unknown
END AS currency_code
```

**Kết quả:** 80+ biến thể → 52 mã chuẩn ISO

---

### Challenge 4: Zero-Price Items (Items giá 0)

**Vấn đề:** 6,022 giao dịch có giá = 0 làm tests thất bại

**Điều tra:**
```sql
SELECT price, COUNT(*) 
FROM unnested_cart 
WHERE price_cleaned = 0
GROUP BY price;

-- Kết quả:
price    | count
---------|------
"0"      | 3,468
"Free"   | 2,554
```

**Nguyên nhân:** Items khuyến mãi/miễn phí hợp lệ
- Free shipping (miễn phí vận chuyển)
- Quà tặng khuyến mãi
- Samples (mẫu thử)
- Bundle discounts

**Quyết định:** Giữ lại zero-price items
```sql
-- Filter cập nhật
WHERE price_original >= 0  -- ✅ Cho phép free items

-- Tests cập nhật
- dbt_utils.expression_is_true:
    expression: ">= 0"  # Đổi từ > 0
```

**Lý do:**
- Lịch sử đơn hàng đầy đủ
- Theo dõi chiến dịch khuyến mãi
- Insights về hành vi khách hàng
- Có thể filter bằng `WHERE price_usd > 0` trong reports

**Tác động:** Thu hồi được tất cả 35,064 giao dịch

---

### Challenge 5: Missing Product References (Thiếu tham chiếu sản phẩm)

**Vấn đề:** 966 đơn hàng tham chiếu đến sản phẩm không có trong catalog

**Điều tra:**
```sql
SELECT 
    COUNT(DISTINCT o.order_id) AS orphaned_orders,
    COUNT(*) AS orphaned_line_items
FROM stg_sales_orders o
LEFT JOIN stg_products p ON o.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Kết quả:
orphaned_orders: 966
orphaned_line_items: 1,053
phần trăm: 3.3%
```

**Giải pháp:** Unknown Member Pattern
```sql
-- Thêm unknown member vào stg_products
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

**Xử lý ở Fact Table:**
```sql
-- Dùng COALESCE để map sản phẩm thiếu về -1
,COALESCE(products.product_key, -1) AS product_key
```

**Cấu hình Test:**
```yaml
- name: product_key
  tests:
    - relationships:
        to: ref('dim_product')
        field: product_key
        config:
          severity: warn  # ✅ Dự kiến 966 orphaned records
```

**Tác động kinh doanh:**
- ✅ Giữ lại tất cả dữ liệu doanh thu
- ✅ Ghi nhận vấn đề chất lượng dữ liệu đã biết
- ✅ Có thể filter bằng `WHERE product_key > 0` khi cần chi tiết sản phẩm
- ❌ 3.3% đơn hàng thiếu metadata sản phẩm

---

## Kết Quả Dự Án

### Kết Quả Định Lượng

#### Metrics Data Warehouse

| Metric | Giá trị | Chi tiết |
|--------|---------|----------|
| **Tổng Giao dịch** | 35,064 | Line item level |
| **Đơn hàng Unique** | 26,031 | Distinct order_ids |
| **Sản phẩm** | 18,820 | Catalog đang hoạt động |
| **Khách hàng** | 15,100 | Users unique |
| **Cửa hàng** | 65 | Quốc tế |
| **Quốc gia** | 150+ | Khách hàng toàn cầu |
| **Khoảng thời gian** | 2019-2029 | 4,017 ngày |
| **Tiền tệ đã chuẩn hóa** | 52 | Từ 80+ biến thể |

#### Metrics Chất Lượng Dữ Liệu

| Metric | Kết quả | Mục tiêu |
|--------|---------|----------|
| **Test Coverage** | 82 tests | 70+ |
| **Tỷ lệ Test Pass** | 98.8% (81/82) | 95%+ |
| **Warnings đã biết** | 1 (đã document) | <5 |
| **Data Completeness** | 96.7% | 95%+ |
| **Zero-Price Items** | 17.2% (giữ cố ý) | N/A |
| **Price Parse Success** | 100% | 100% |
| **Currency Normalization** | 100% | 100% |

#### Metrics Hiệu Suất

| Metric | Giá trị | Mục tiêu |
|--------|---------|----------|
| **Thời gian Full Rebuild** | 12-16 giây | <30s |
| **Thời gian Test** | 40-45 giây | <60s |
| **Thời gian Query Mart** | <1 giây | <2s |
| **Thời gian Load Dashboard** | 2-3 giây | <5s |

---

## Framework Kiểm Tra (Testing)

### Tổng Quan

**Tổng Coverage:** 82 kiểm tra chất lượng dữ liệu trên tất cả các tầng  
**Tỷ lệ thành công:** 98.8% (81 PASS, 1 WARN, 0 ERROR)  
**Định nghĩa Test:** Tất cả tests được định nghĩa trong các file `schema.yml`

### Phân Bố Tests
```
models/
├── staging/schema.yml           # 24 tests - Kiểm tra làm sạch dữ liệu
├── dimensions/schema.yml        # 36 tests - Tính toàn vẹn dữ liệu tham chiếu
├── facts/schema.yml             # 21 tests - Kiểm tra metrics giao dịch
└── marts/schema.yml             # 1 test  - Giới hạn dữ liệu đã biết (WARNING)
```

### Các Loại Kiểm Tra

#### 1. **Data Integrity (40 tests)**
- **Not Null:** Các trường quan trọng phải có giá trị (31 tests)
- **Unique:** Primary keys phải unique (9 tests)

**Mục đích:** Đảm bảo không có dữ liệu thiếu ở các trường chính

---

#### 2. **Referential Integrity (7 tests)**
- **Relationships:** Foreign keys tồn tại trong parent tables

**Mục đích:** Đảm bảo JOINs không tạo orphaned records (trừ trường hợp đã document)

**Trường hợp đặc biệt - Warning đã biết:**
```yaml
- name: product_key
  tests:
    - relationships:
        config:
          severity: warn  # 966 orders (3.3%) có discontinued products
```

---

#### 3. **Business Rules (32 tests)**
- **Expression Validation:** Logic tùy chỉnh sử dụng dbt_utils

**Mục đích:** Thực thi các ràng buộc kinh doanh về giá trị dữ liệu

**Ví dụ:**
```yaml
# Giá có thể bằng 0 (cho phép free items)
- name: price_original
  tests:
    - dbt_utils.expression_is_true:
        expression: ">= 0"

# Số lượng phải dương
- name: quantity
  tests:
    - dbt_utils.expression_is_true:
        expression: "> 0"
```

---

#### 4. **Data Quality Constraints (3 tests)**
- **Accepted Values:** Giới hạn các giá trị hợp lệ đã biết

---

### Chạy Tests
```bash
# Chạy tất cả 82 tests
dbt test

# Kết quả mong đợi:
# PASS=81 WARN=1 ERROR=0 SKIP=0 TOTAL=82

# Chạy tests cho model cụ thể
dbt test --select stg_sales_orders

# Chạy tests cho tầng cụ thể
dbt test --select staging        # 24 tests
dbt test --select dimensions     # 36 tests
dbt test --select facts          # 21 tests
```

---

### Warning Duy Nhất (Dự Kiến)

**Warning:** 966 đơn hàng tham chiếu đến sản phẩm không có trong catalog

**Ý nghĩa:**
- 3.3% đơn hàng thiếu chi tiết sản phẩm
- Sản phẩm đã bị discontinued sau khi scraping
- **Quyết định kinh doanh:** Giữ dữ liệu doanh thu, chấp nhận thiếu thuộc tính sản phẩm

**Tác động:**
- ✅ Giữ lại tất cả dữ liệu doanh thu
- ❌ 3.3% đơn hàng thiếu chi tiết sản phẩm

**Cách xử lý:**
```sql
-- Filter sản phẩm unknown khi cần thuộc tính sản phẩm
WHERE product_key > 0
```

---

## Bài Học Chính

### Kỹ Năng Kỹ Thuật Đạt Được

#### 1. SQL Nâng Cao
- **UNNEST** để xử lý arrays
- **Regex** để pattern matching
- **Window functions** cho customer metrics
- **SAFE_CAST** để xử lý lỗi

#### 2. Best Practices dbt
- **Staging layer:** Chỉ clean và normalize, không có business logic
- **Dimension layer:** Xây dựng slowly-changing dimensions
- **Fact layer:** Lưu metrics và foreign keys
- **Mart layer:** Denormalize cho BI consumption
- **Testing:** 80% coverage trên các trường quan trọng
- **Documentation:** Mỗi model và field đều được document

#### 3. Nguyên Tắc Data Modeling
- **Star schema:** Fact table được bao quanh bởi dimensions
- **Surrogate keys:** Dùng hash-based keys cho performance
- **Unknown members:** Xử lý missing reference data một cách graceful
- **Grain:** Define và document grain của fact table
- **Slowly changing dimensions:** Theo dõi customer metrics theo thời gian

#### 4. Tối Ưu BigQuery
- **Partitioning** cho time-based queries
- **Clustering** cho common filters
- **Table vs View:** Views cho Staging, Tables cho Dimensions/Facts/Marts

#### 5. Framework Data Quality
- **Not Null:** Các trường quan trọng phải có giá trị
- **Unique:** Primary keys phải unique
- **Relationships:** Foreign keys phải tồn tại trong parent table
- **Accepted Values:** Giới hạn giá trị đã biết
- **Custom Tests:** Validation business logic

---

### Bài Học Quy Trình

#### 1. Phát Triển Từng Bước

**Hiệu quả:**
- Xây từng layer một (staging → dimensions → facts)
- Test mỗi model trước khi tiếp tục
- Dùng `dbt run --select model_name` để iterate nhanh

**Không hiệu quả:**
- Xây toàn bộ data warehouse trước khi test
- Thay đổi nhiều thứ cùng lúc
- Bỏ qua documentation đến cuối cùng

#### 2. Quản Lý Chất Lượng Dữ Liệu

**Insights quan trọng:**
- **Document known issues** thay vì che giấu
- **Dùng test severity levels** (error vs warn)
- **Filter bad data tại source** để tránh cascading failures
- **Communicate data limitations** với stakeholders

#### 3. Giao Tiếp Stakeholder

**Bài học:**
- **Minh bạch** về giới hạn dữ liệu
- **Định lượng tác động** (3.3% đơn hàng bị ảnh hưởng)
- **Giải thích trade-offs** (giữ doanh thu vs mất chi tiết sản phẩm)
- **Cung cấp workarounds** (filter WHERE product_key > 0)

---

### Bài Học Business Intelligence

#### 1. Hiểu Business Context

**Câu hỏi quan trọng:**
- Tại sao có zero-price items? → Khuyến mãi (giữ lại!)
- Tại sao thiếu sản phẩm? → Discontinued (document!)
- Tại sao nhiều loại tiền tệ? → Kinh doanh quốc tế (chuẩn hóa!)
- Grain nào cho fact table? → Line item (business cần chi tiết)

#### 2. Cân Bằng Completeness vs Quality

**Ví dụ Trade-off:**
```
Option A: Loại bỏ 966 orphaned orders (3.3%)
  ✅ 100% chất lượng dữ liệu
  ❌ Mất dữ liệu doanh thu
  ❌ Tổng số không chính xác

Option B: Giữ orphaned orders, đánh dấu "Unknown Product"
  ✅ Dữ liệu doanh thu đầy đủ
  ✅ Giới hạn đã được document
  ❌ 3.3% thiếu thuộc tính sản phẩm
  
Quyết định: Option B (business ưu tiên completeness)
```

#### 3. Performance vs Usability

**Quyết định thiết kế Mart:**
```
Multiple Marts:
  ✅ Performance tốt hơn
  ✅ Tables nhỏ hơn
  ❌ Phức tạp cho business users
  ❌ Nhiều data sources trong Looker

One Big Table:
  ✅ Single data source
  ✅ Không cần JOINs trong BI
  ✅ Đơn giản drag-and-drop
  ❌ Table lớn hơn một chút

Quyết định: OBT (35K rows có thể quản lý được, usability > micro-optimization)
```

---

## Cấu Trúc Repository
```
k20_de_2025/
├── README.md                        # Tài liệu tiếng Anh
├── README_VI.md                     # Tài liệu tiếng Việt (file này)
├── .gitignore
├── dbt_project.yml
├── packages.yml
│
├── models/
│   ├── staging/
│   │   ├── sources.yml              # Định nghĩa sources
│   │   ├── schema.yml               # 24 tests
│   │   ├── stg_sales_orders.sql
│   │   ├── stg_products.sql
│   │   └── stg_ip_locations.sql
│   │
│   ├── dimensions/
│   │   ├── schema.yml               # 36 tests
│   │   ├── dim_date.sql
│   │   ├── dim_product.sql
│   │   ├── dim_customer.sql
│   │   ├── dim_store.sql
│   │   ├── dim_location.sql
│   │   └── dim_currency_rate.sql
│   │
│   ├── facts/
│   │   ├── schema.yml               # 21 tests
│   │   └── fact_sales_order_tt.sql
│   │
│   └── marts/
│       ├── schema.yml               # 1 test
│       └── mart_sales_complete.sql
│
├── seeds/
│   └── currency_rates.csv
│
└── tests/
    └── (custom tests)
```

---

## Lệnh dbt Thường Dùng
```bash
# Cài đặt
pip install dbt-bigquery

# Khởi tạo project
dbt init project_name

# Chạy models
dbt run                              # Chạy tất cả models
dbt run --select model_name          # Chạy model cụ thể
dbt run --select model_name+         # Chạy model + downstream
dbt run --full-refresh               # Drop và tạo lại

# Chạy tests
dbt test                             # Chạy tất cả tests
dbt test --select model_name         # Test model cụ thể

# Seeds
dbt seed                             # Load tất cả seeds
dbt seed --full-refresh              # Reload seeds

# Documentation
dbt docs generate                    # Tạo docs
dbt docs serve                       # Xem docs locally

# Build (run + test + seed)
dbt build                            # Tất cả
```
---

**📖 For English version, see [README.md](README.md)**

EOF
