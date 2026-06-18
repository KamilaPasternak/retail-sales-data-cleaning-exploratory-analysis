-- empty values
SELECT 
   COUNT(*),
   COUNT(order_date) as NOT_NULL_DATES,
   COUNT(discount_pct) as NOT_NULL_DISCOUNT
FROM staging.sales_orders;

SELECT
    SUM(CASE WHEN order_date IS NULL then 1 else 0 end) AS NULL_DATES,
    SUM(CASE WHEN order_date = '' then 1 else 0 end) AS EMPTY_STRINGS
FROM staging.sales_orders;

SELECT 
   COUNT(*),
   SUM(CASE WHEN order_date = '' then 1 else 0 end) AS MISSING_DATES,
   ROUND(100.0*SUM(CASE WHEN order_date IS NULL OR order_date = '' then 1 else 0 end)/COUNT(*),2) AS PERCENT
FROM staging.sales_orders;
   
-- duplicates
SELECT order_id, COUNT(*)
FROM staging.sales_orders
GROUP BY order_id
HAVING COUNT(*)>1
ORDER BY COUNT(*) desc;   

-- removing duplicates
create or replace view sales_dedup as
SELECT *
FROM (
SELECT *,
row_number() over (partition by order_id
ORDER BY order_id) as rn
FROM staging.sales_orders
)t
WHERE rn = 1; 
 
-- date format
SELECT DISTINCT order_date
FROM staging.sales_orders
LIMIT 20;

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

-- standardization of countries
SELECT DISTINCT country FROM sales_with_date
ORDER BY country;

create or replace view sales_clean as
SELECT *,
    case
        when lower(country) in ('at','austria') THEN 'Austria'
        when lower(country) in ('cz','czech','czech republic','czechia') THEN 'Czech Republic'
	    when lower(country) in ('de','ger','germany','deutschland') THEN 'Germany'
        when lower(country) in ('es','spain') THEN 'Spain'
        when lower(country) in ('fr','france') THEN 'France'
        when lower(country) in ('holland','netherlands','nl') THEN 'Netherlands'
        when lower(country) in ('it','italy') THEN 'Italy'
        when lower(country) in ('pl','poland','polska','pol') THEN 'Poland'
        when lower(country) in ('se','sweden') THEN 'Sweden'
        when lower(country) in ('sk','slovak','slovakia') THEN 'Slovakia'
        else country
	end as country_clean
FROM sales_with_date;

SELECT DISTINCT country_clean 
FROM sales_clean
ORDER BY country_clean;

-- normalization of status
select distinct status from sales_clean
ORDER BY status;

create or replace view sales_cleaned as
SELECT *,
    CASE
        WHEN UPPER(status) IN ('COMPLETE', 'COMPLETED', 'DONE') THEN 'COMPLETED'
        WHEN UPPER(status) IN ('SHIP', 'SHIPPED') THEN 'SHIPPED'
        WHEN UPPER(status) = 'CANCELLED' THEN 'CANCELLED'
        ELSE 'OTHER'
    END AS status_clean
FROM sales_clean;

select distinct status_clean from sales_cleaned
ORDER BY status_clean;

-- normalization of the discount column
SELECT 
    SUM(CASE WHEN discount_pct IS NULL then 1 else 0 end) AS NULL_DISC,
    SUM(CASE WHEN discount_pct = '' then 1 else 0 end) AS EMPTY_STRINGS
FROM sales_cleaned;

SELECT discount_pct
FROM sales_cleaned
WHERE discount_pct NOT REGEXP '^[0-9]+(\\.[0-9]+)?$';

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

SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN discount_pct_clean IS NULL THEN 1 ELSE 0 END) AS null_values,
    SUM(CASE WHEN TRIM(discount_pct_clean) = '' THEN 1 ELSE 0 END) AS empty_strings
FROM sales_standardized;

SELECT * FROM sales_standardized;

-- empty values
SELECT 
    COUNT(*),
    COUNT(base_price) AS NOT_NULL_PRICE,
    COUNT(launch_date) AS NOT_NULL_LDATES
FROM
    staging.products;

SELECT 
    SUM(CASE
        WHEN launch_date IS NULL THEN 1
        ELSE 0
    END) AS NULL_LDATES,
    SUM(CASE
        WHEN launch_date = '' THEN 1
        ELSE 0
    END) AS EMPTY_STRINGS
FROM
    staging.products;

SELECT 
    COUNT(*),
    SUM(CASE
        WHEN launch_date = '' THEN 1
        ELSE 0
    END) AS MISSING_DATES,
    ROUND(100.0 * SUM(CASE
                WHEN launch_date IS NULL OR launch_date = '' THEN 1
                ELSE 0
            END) / COUNT(*),
            2) AS PERCENT
FROM
    staging.products;

SELECT 
    SUM(CASE
        WHEN base_price IS NULL THEN 1
        ELSE 0
    END) AS NULL_PRICE,
    SUM(CASE
        WHEN base_price = '' THEN 1
        ELSE 0
    END) AS EMPTY_STRINGS
FROM
    staging.products;

-- duplicates
SELECT 
    product_id, COUNT(*)
FROM
    staging.products
GROUP BY product_id
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;

-- standardization of categories
SELECT DISTINCT
    category
FROM
    staging.products
ORDER BY category;

SELECT DISTINCT
    sub_category
FROM
    staging.products
ORDER BY sub_category;

-- outliers prices
SELECT 
    MIN(base_price), MAX(base_price)
FROM
    staging.products;

-- date format
CREATE OR REPLACE VIEW products_clean AS
    SELECT *,
        CASE
            WHEN launch_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(launch_date, '%Y-%m-%d')
            WHEN launch_date REGEXP '^[0-9]{4}/[0-9]{2}/[0-9]{2}$' THEN STR_TO_DATE(launch_date, '%Y/%m/%d')
            WHEN launch_date REGEXP '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$' THEN STR_TO_DATE(launch_date, '%Y.%m.%d')
            WHEN launch_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN STR_TO_DATE(launch_date, '%d-%m-%Y')
            WHEN launch_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN STR_TO_DATE(launch_date, '%d/%m/%Y')
            ELSE NULL
        END AS launch_DT
    FROM
        staging.products;

SELECT * FROM products_clean;

-- empty values
SELECT 
    COUNT(*),
    COUNT(warehouse_country) AS NOT_NULL_COUNTRY,
    COUNT(stock_quantity) AS NOT_NULL_STOCK,
    COUNT(last_stock_update) AS NOT_NULL_DATES
FROM
    staging.inventory;

SELECT 
    SUM(CASE
        WHEN last_stock_update IS NULL THEN 1
        ELSE 0
    END) AS NULL_DATE,
    SUM(CASE
        WHEN last_stock_update = '' THEN 1
        ELSE 0
    END) AS EMPTY_STRINGS
FROM
    staging.inventory;

-- duplicates
SELECT 
    product_id, warehouse_country, COUNT(*)
FROM
    staging.inventory
GROUP BY product_id , warehouse_country
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;

-- countries cleaning
SELECT DISTINCT
    warehouse_country
FROM
    staging.inventory
ORDER BY warehouse_country;

CREATE OR REPLACE VIEW inventory_country_clean AS
    SELECT *,
        CASE
            WHEN LOWER(warehouse_country) IN ('cz' , 'czech', 'czech republic', 'czechia') THEN 'Czech Republic'
            WHEN LOWER(warehouse_country) IN ('de' , 'ger', 'germany', 'deutschland') THEN 'Germany'
            WHEN LOWER(warehouse_country) IN ('pl' , 'poland', 'polska', 'pol') THEN 'Poland'
            ELSE warehouse_country
        END AS country_clean
    FROM
        staging.inventory;

SELECT DISTINCT
    country_clean
FROM
    inventory_country_clean
ORDER BY country_clean;

-- date format
CREATE OR REPLACE VIEW inventory_clean AS
    SELECT *,
        CASE
            WHEN last_stock_update REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(last_stock_update, '%Y-%m-%d')
            WHEN last_stock_update REGEXP '^[0-9]{4}/[0-9]{2}/[0-9]{2}$' THEN STR_TO_DATE(last_stock_update, '%Y/%m/%d')
            WHEN last_stock_update REGEXP '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$' THEN STR_TO_DATE(last_stock_update, '%Y.%m.%d')
            WHEN last_stock_update REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN STR_TO_DATE(last_stock_update, '%d-%m-%Y')
            WHEN last_stock_update REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN STR_TO_DATE(last_stock_update, '%d/%m/%Y')
            ELSE NULL
        END AS last_stock_DT
    FROM
        inventory_country_clean;

SELECT * FROM inventory_clean
ORDER BY last_stock_DT DESC;

SELECT * FROM products_clean;