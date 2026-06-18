-- outliers
SELECT 
    MIN(quantity),
    MAX(quantity),
    MIN(unit_price),
    MAX(unit_price)
FROM
    sales_standardized;

CREATE OR REPLACE VIEW sales_analysis AS
    SELECT *
    FROM
        sales_standardized
    WHERE
        quantity BETWEEN 1 AND 100
            AND unit_price > 0;

-- revenue year by year
SELECT 
    YEAR(order_DT) AS year,
    SUM(quantity * unit_price) AS revenue,
    SUM(quantity) AS total_quantity,
    ROUND(SUM(quantity * unit_price) / SUM(quantity), 0) AS avg_price
FROM
    sales_analysis
GROUP BY YEAR(order_DT)
ORDER BY year;

-- revenue countries
SELECT 
    country_clean,
    YEAR(order_DT) AS year,
    SUM(quantity * unit_price) AS revenue,
    SUM(quantity) AS total_quantity,
    ROUND(SUM(quantity * unit_price) / SUM(quantity), 0) AS avg_price
FROM sales_analysis
WHERE order_DT IS NOT NULL
GROUP BY country_clean, YEAR(order_DT)
ORDER BY country_clean, year;

-- quantity by country
SELECT
    country_clean,
    SUM(quantity) AS total_quantity
FROM sales_analysis
WHERE order_DT IS NOT NULL
GROUP BY country_clean
ORDER BY total_quantity DESC;

-- seasonality
SELECT 
    DATE_FORMAT(order_DT, '%Y-%m') AS month,
    SUM(quantity * unit_price) AS revenue
FROM
    sales_analysis
GROUP BY 1
ORDER BY 1;

-- categories
SELECT 
    p.category,
    SUM(s.quantity * s.unit_price) AS revenue,
    SUM(s.quantity) AS total_quantity,
    ROUND(SUM(s.quantity * s.unit_price) / SUM(s.quantity), 0) AS avg_price
FROM sales_analysis s
JOIN products_clean p
    ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue DESC;

-- category by years
SELECT 
    p.category,
    YEAR(s.order_DT) AS year,
    SUM(s.quantity * s.unit_price) AS revenue
FROM sales_analysis s
JOIN products_clean p
    ON s.product_id = p.product_id
GROUP BY p.category, YEAR(s.order_DT)
ORDER BY year, revenue DESC;

-- category_by_month (seasonality)
SELECT 
    p.category,
    MONTH(s.order_DT) AS month_num,
    MONTHNAME(s.order_DT) AS month_name,
    SUM(s.quantity * s.unit_price) AS revenue
FROM sales_analysis s
JOIN products_clean p
    ON s.product_id = p.product_id
GROUP BY p.category, MONTH(s.order_DT), MONTHNAME(s.order_DT)
ORDER BY p.category, month_num;

-- cheap vs expensive sub_categories
SELECT 
    p.sub_category,
    ROUND(AVG(p.base_price), 0) AS avg_base_price,
    SUM(s.quantity) AS total_quantity,
    SUM(s.quantity * s.unit_price) AS revenue
FROM sales_analysis s
JOIN products_clean p
    ON s.product_id = p.product_id
GROUP BY p.sub_category
ORDER BY avg_base_price DESC;

-- discount impact
SELECT 
    ROUND(AVG(CASE WHEN discount_pct_clean > 0 THEN discount_pct_clean END), 2) AS avg_discount,
    MIN(CASE WHEN discount_pct_clean > 0 THEN discount_pct_clean END) AS min_discount,
    MAX(CASE WHEN discount_pct_clean > 0 THEN discount_pct_clean END) AS max_discount,
    SUM(CASE WHEN discount_pct_clean > 0 THEN 1 ELSE 0 END) AS orders_with_discount,
    SUM(CASE WHEN discount_pct_clean = 0 THEN 1 ELSE 0 END) AS orders_without_discount,
    SUM(CASE WHEN discount_pct_clean IS NULL THEN 1 ELSE 0 END) AS missing_discount_data
FROM sales_analysis;

-- discount_by_country
SELECT
    country_clean,
    ROUND(AVG(CASE WHEN discount_pct_clean > 0 THEN discount_pct_clean END), 2) AS avg_discount,
	MIN(CASE WHEN discount_pct_clean > 0 THEN discount_pct_clean END) AS min_discount,
    MAX(CASE WHEN discount_pct_clean > 0 THEN discount_pct_clean END) AS max_discount,
	SUM(CASE WHEN discount_pct_clean > 0 THEN 1 ELSE 0 END) AS orders_with_discount,
    SUM(CASE WHEN discount_pct_clean = 0 THEN 1 ELSE 0 END) AS orders_without_discount,
    SUM(CASE WHEN discount_pct_clean IS NULL THEN 1 ELSE 0 END) AS missing_discount_data
FROM sales_analysis
GROUP BY country_clean
ORDER BY avg_discount DESC;

-- discount_by_category
SELECT
    p.category,
	ROUND(AVG(CASE WHEN s.discount_pct_clean > 0 THEN s.discount_pct_clean END), 2) AS avg_discount,
	MIN(CASE WHEN s.discount_pct_clean > 0 THEN s.discount_pct_clean END) AS min_discount,
    MAX(CASE WHEN s.discount_pct_clean > 0 THEN s.discount_pct_clean END) AS max_discount,
	SUM(CASE WHEN s.discount_pct_clean > 0 THEN 1 ELSE 0 END) AS orders_with_discount,
    SUM(CASE WHEN s.discount_pct_clean = 0 THEN 1 ELSE 0 END) AS orders_without_discount,
    SUM(CASE WHEN s.discount_pct_clean IS NULL THEN 1 ELSE 0 END) AS missing_discount_data
FROM sales_analysis s
JOIN products_clean p
    ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY avg_discount DESC;

--  discount_impact
SELECT
    CASE
        WHEN discount_pct_clean > 0 AND discount_pct_clean <= 10 THEN '0-10%'
        WHEN discount_pct_clean > 10 AND discount_pct_clean <= 20 THEN '10-20%'
        WHEN discount_pct_clean > 20 AND discount_pct_clean <= 30 THEN '20-30%'
        WHEN discount_pct_clean > 30 THEN '30%+'
    END AS discount_group,
    ROUND(AVG(quantity), 2) AS avg_quantity,
    ROUND(SUM(quantity), 0) AS total_quantity,
    ROUND(AVG(quantity * unit_price), 0) AS avg_revenue
FROM sales_analysis
WHERE discount_pct_clean > 0
GROUP BY discount_group
ORDER BY 
    CASE
        WHEN discount_group = '0-10%' THEN 1
        WHEN discount_group = '10-20%' THEN 2
        WHEN discount_group = '20-30%' THEN 3
        WHEN discount_group = '30%+' THEN 4
    END;

-- intentory
SELECT 
    country_clean,
    COUNT(*) AS total_products,
    SUM(CASE 
        WHEN stock_quantity <= 15 AND last_stock_DT > '2023-06-30' THEN 1 
        ELSE 0 END) AS low_stock_only,
    SUM(CASE 
        WHEN stock_quantity > 15 AND last_stock_DT <= '2023-06-30' THEN 1 
        ELSE 0 END) AS outdated_only,	
    SUM(CASE 
        WHEN stock_quantity <= 15 AND last_stock_DT <= '2023-06-30' THEN 1 
        ELSE 0 END) AS both_issues
FROM inventory_clean
GROUP BY country_clean;

-- overstocked
CREATE OR REPLACE VIEW inventory_sales AS
SELECT 
    i.product_id,
    i.country_clean,
    i.stock_quantity,
    COALESCE(s.total_sales, 0) AS sales
FROM inventory_clean i
LEFT JOIN (
    SELECT 
        product_id,
        country_clean,
	    SUM(quantity) AS total_sales
    FROM sales_analysis
    WHERE order_DT >= '2024-07-01'
    GROUP BY product_id, country_clean
) s 
ON i.product_id = s.product_id 
AND i.country_clean = s.country_clean;

SELECT 
    country_clean,
    COUNT(*) AS total_products,
    SUM(CASE WHEN inventory_status = 'Dead Stock' THEN 1 ELSE 0 END) AS dead_stock,
    SUM(CASE WHEN inventory_status = 'Extreme Overstock' THEN 1 ELSE 0 END) AS extreme_overstock,
    SUM(CASE WHEN inventory_status = 'Overstock' THEN 1 ELSE 0 END) AS overstock,
    SUM(CASE WHEN inventory_status = 'Healthy' THEN 1 ELSE 0 END) AS health
FROM (
    SELECT 
        product_id,
        country_clean,
        stock_quantity,
        sales,
        CASE 
            WHEN sales = 0 AND stock_quantity > 0 THEN 'Dead Stock'
            WHEN stock_quantity / NULLIF(sales,0) > 50 THEN 'Extreme Overstock'
            WHEN stock_quantity / NULLIF(sales,0) > 20 THEN 'Overstock'
            ELSE 'Healthy'
        END AS inventory_status
    FROM inventory_sales
) t
GROUP BY country_clean;