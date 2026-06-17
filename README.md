# Retail-Sales-Data-Cleaning-Exploratory-Analysis
Performed data quality checks, data cleaning, SQL analyses, and data preparation for reporting.

## Data Cleaning Process
### 1. Missing Values Assessment

The first step was to evaluate data completeness across the sales, products, and inventory tables.
```sql
SELECT
    COUNT(*) AS total_rows,
    COUNT(order_date) AS not_null_dates,
    COUNT(discount_pct) AS not_null_discount
FROM staging.sales_orders;
```
No null values were found in the `order_date` and `discount_pct` field in `sales_orders` table.
Next, I checked `order_date` column for the number of empty strings.
```sql
SELECT
    SUM(CASE WHEN order_date IS NULL then 1 else 0 end) AS NULL_DATES,
    SUM(CASE WHEN order_date = '' then 1 else 0 end) AS EMPTY_STRINGS
FROM staging.sales_orders;
```
### Problem
The dataset contained empty strings in the `order_date` column.

### Approach
I calculated the percentage of missing values and evaluated their potential impact on the analysis.
```sql
SELECT 
   COUNT(*),
   SUM(CASE WHEN order_date = '' then 1 else 0 end) AS MISSING_DATES,
   ROUND(100.0*SUM(CASE WHEN order_date IS NULL OR order_date = '' then 1 else 0 end)/COUNT(*),2) AS PERCENT
FROM staging.sales_orders;
```
### Findings
Approximately 0.2% of records contained empty strings in `order_date`. Missing order dates were retained because they did not affect the main sales and seasonality analyses.

### Problem
I also checked the `discount_pct` column and found empty strings there as well. The percentage of missing values was approximately 12.0%, which is significant for the analysis. Furthermore, the `discount_pct` field was stored as text and contained percentage symbols as well as invalid entries. 

### Approach
I removed formatting characters, validated numeric values using regular expressions, and converted the field to a numeric format suitable for analysis. Invalid values were replaced with NULL to ensure data quality.
```sql
CREATE OR REPLACE VIEW sales_standardized AS
SELECT *,
    CASE 
        WHEN TRIM(REPLACE(discount_pct, '%', '')) 
             REGEXP '^[0-9]+(\\.[0-9]+)?$'
        THEN CAST(
            TRIM(REPLACE(discount_pct, '%', ''))
            AS DECIMAL(5,2))
        ELSE NULL
    END AS discount_pct_clean
FROM sales_cleaned;
```
### Findings
