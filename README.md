# Retail Sales - Data Cleaning [SQL]
## Skills Demonstrated

* SQL Data Cleaning - missing values and duplicates
* Window Functions
* Data Standardization - consistent format
* Data Validation - outliers and invalid data

## Data Cleaning Process

## 1. Missing Values Assessment

The first step was to evaluate data completeness across the sales, products, and inventory tables.
```sql
SELECT
    COUNT(*) AS total_rows,
    COUNT(order_date) AS not_null_dates,
    COUNT(discount_pct) AS not_null_discount
FROM staging.sales_orders;
```
<img width="416" height="65" alt="image" src="https://github.com/user-attachments/assets/f637d742-0259-446f-8431-5f7cf26cc64e" />

No null values were found in the `order_date` and `discount_pct` field in `sales_orders` table.
Next, I checked `order_date` column for the number of empty strings.
```sql
SELECT
    SUM(CASE WHEN order_date IS NULL then 1 else 0 end) AS NULL_DATES,
    SUM(CASE WHEN order_date = '' then 1 else 0 end) AS EMPTY_STRINGS
FROM staging.sales_orders;
```
<img width="267" height="55" alt="image" src="https://github.com/user-attachments/assets/1a48ce5a-d8db-4131-a5ba-fe2275b1fc12" />

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
<img width="317" height="61" alt="image" src="https://github.com/user-attachments/assets/6ee0a71f-c9dd-4c88-bae9-ceb96dbf1694" />

### Findings
Approximately 0.24% of records contained empty strings in `order_date`. Missing order dates were retained because they did not affect the main sales and seasonality analyses.

I also examined the `discount_pct` column for the presence of empty strings.

<img width="342" height="52" alt="image" src="https://github.com/user-attachments/assets/ead1c1f0-a0ac-449b-a353-d5957c6985b5" />

### Problem
I also found empty strings there as well. The percentage of missing values was approximately 12.0%, which is significant for the analysis. Furthermore, the `discount_pct` field was stored as text and contained percentage symbols as well as invalid entries. 

### Approach
I removed formatting characters, validated numeric values using regular expressions, and converted the field to a numeric format suitable for analysis. Missing values were replaced with NULL to ensure data quality.
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
Despite NULL values still representing approximately 12% of the dataset, the analysis proceeded. Discount values were classified into three categories: missing values (NULL), orders without discounts (0%), and orders with active discounts (>0%).

The remaining columns examined, including `launch_date`, `base_price`, and `last_stock_update`, had a negligible level of missing data that was not considered significant for further analysis.

## 2. Duplicate Removing

I started by identifying duplicate transactions using the query below.
```sql
SELECT 
    order_id, COUNT(*)
FROM
    staging.sales_orders
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC; 
```
Then, I removed duplicates using a window function:
```sql
CREATE OR REPLACE VIEW sales_dedup AS
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY order_id
               ORDER BY order_id
           ) AS rn
    FROM staging.sales_orders
) t
WHERE rn = 1;
```

## 3. Date Standardization

### Problem
The dataset contained multiple date formats.

Examples:

<img width="138" height="173" alt="image" src="https://github.com/user-attachments/assets/246dc13c-2a3d-4c0c-9924-fd9cf91374bd" />

### Approach
I looked for different date formats and standardized them using the query below.
```sql
CREATE OR REPLACE VIEW sales_with_date AS
SELECT *,
    CASE 
        WHEN order_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' 
            THEN STR_TO_DATE(order_date, '%Y-%m-%d')
        WHEN order_date REGEXP '^[0-9]{4}/[0-9]{2}/[0-9]{2}$' 
            THEN STR_TO_DATE(order_date, '%Y/%m/%d')
        WHEN order_date REGEXP '^[0-9]{4}\\.[0-9]{2}\\.[0-9]{2}$' 
            THEN STR_TO_DATE(order_date, '%Y.%m.%d')
        WHEN order_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' 
            THEN STR_TO_DATE(order_date, '%d-%m-%Y')
        WHEN order_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' 
            THEN STR_TO_DATE(order_date, '%d/%m/%Y')
        ELSE NULL
    END AS order_DT
FROM sales_dedup;
```
### Findings
A standardized date column was created.

<img width="137" height="174" alt="image" src="https://github.com/user-attachments/assets/f3a9456f-4e3b-4f42-8e09-58ba54b1bb2d" />

## 4. Country Standardization

### Problem
Country names appeared in multiple formats.

Examples:

<img width="131" height="178" alt="image" src="https://github.com/user-attachments/assets/de04f988-aaf2-4b92-a65a-0a5e4bdb79ba" />

### Approach
I selected and sorted distinct country names to identify inconsistencies and standardize the data using the query below.
```sql
CREATE OR REPLACE VIEW sales_clean AS
    SELECT *,
        CASE
            WHEN LOWER(country) IN ('at' , 'austria') THEN 'Austria'
            WHEN LOWER(country) IN ('cz' , 'czech', 'czech republic', 'czechia') THEN 'Czech Republic'
            WHEN LOWER(country) IN ('de' , 'ger', 'germany', 'deutschland') THEN 'Germany'
            WHEN LOWER(country) IN ('es' , 'spain') THEN 'Spain'
            WHEN LOWER(country) IN ('fr' , 'france') THEN 'France'
            WHEN LOWER(country) IN ('holland' , 'netherlands', 'nl') THEN 'Netherlands'
            WHEN LOWER(country) IN ('it' , 'italy') THEN 'Italy'
            WHEN LOWER(country) IN ('pl' , 'poland', 'polska', 'pol') THEN 'Poland'
            WHEN LOWER(country) IN ('se' , 'sweden') THEN 'Sweden'
            WHEN LOWER(country) IN ('sk' , 'slovak', 'slovakia') THEN 'Slovakia'
            ELSE country
        END AS country_clean
    FROM
        sales_with_date;
```
### Findings
I checked the distinct values in the country column to ensure that only one standardized version of each country name remained. This is how the example dataset looks after the standardization process. 

<img width="148" height="177" alt="image" src="https://github.com/user-attachments/assets/64ac86de-da1e-47b5-bd9c-02c32ed56deb" />

In the same way, I standardized multiple status labels and merged them into three business-friendly categories.

## 5. Value Normalization

I started by preparing the data and checking for outliers in the `quantity` and `unit_price` columns.
```sql
SELECT 
    MIN(quantity),
    MAX(quantity),
    MIN(unit_price),
    MAX(unit_price)
FROM
    sales_standardized;
```
<img width="477" height="53" alt="image" src="https://github.com/user-attachments/assets/c35fd201-c6ba-4141-a221-527a76572099" />

### Problem
The minimum values for both `quantity` and `unit_price` were 0, which do not make sense for further analysis. Therefore, it was necessary to apply a condition ensuring that `quantity` is greater or equal than 1 and `unit_price` is greater than 0.

However, these results alone did not provide much insight into potential outliers, as the distribution of the data was still unknown. 

### Approach
I exported the dataset to a CSV file and created histograms for both columns.

### Findings
<img width="1171" height="678" alt="image" src="https://github.com/user-attachments/assets/61df7abc-d62c-4cdd-ba86-e343f226940d" />

The histogram shows that most observations fall between 0 and 10, while a small number of potential outliers in `quantity` can be observed around the value of 600.

<img width="1233" height="644" alt="image" src="https://github.com/user-attachments/assets/db38c3c1-df6f-4226-8473-1be84a3bbee7" />

This histogram appears to be approximately normally distributed, with no obvious or significant outliers.

At this point, I could use the following query to filter out outliers, resulting in a cleaned dataset ready for further analysis.
```sql
CREATE OR REPLACE VIEW sales_analysis AS
    SELECT *
    FROM
        sales_standardized
    WHERE
        quantity BETWEEN 1 AND 100
            AND unit_price > 0;
```
## Conclusion
The raw datasets contained several common data quality issues, including duplicate records, inconsistent date formats, non-standardized categorical values, and missing data.

As a result, a clean and reliable analytical dataset was created, providing a solid foundation for further sales, pricing, seasonality, and inventory analysis.
