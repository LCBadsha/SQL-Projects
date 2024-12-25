-- 1. List the markets in which the customer "Atliq Exclusive" operates in the APAC region.
CREATE VIEW region AS
SELECT market
FROM dim_customer
WHERE customer = 'Atliq Exclusive'
  AND region = 'APAC';

-- 2. Calculate the percentage of unique product increase in 2021 vs. 2020.
CREATE VIEW Unique_product_increase AS
WITH FY_2020 AS (
    SELECT COUNT(DISTINCT product_code) AS unique_products_2020
    FROM fact_sales_monthly
    WHERE fiscal_year = 2020
),
FY_2021 AS (
    SELECT COUNT(DISTINCT product_code) AS unique_products_2021
    FROM fact_sales_monthly
    WHERE fiscal_year = 2021
)
SELECT 
    unique_products_2020, 
    unique_products_2021, 
    ((unique_products_2021 - unique_products_2020) / unique_products_2020 * 100) AS percentage_change
FROM FY_2020
CROSS JOIN FY_2021;

-- 3. Report unique product counts for each segment, sorted in descending order.
CREATE VIEW product_count AS
SELECT segment, 
       COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- 4. Identify the segment with the most increase in unique products from 2020 to 2021.
CREATE VIEW question_4 AS
SELECT 
    segment, 
    COUNT(DISTINCT CASE WHEN b.fiscal_year = 2020 THEN a.product_code END) AS product_count_2020,
    COUNT(DISTINCT CASE WHEN b.fiscal_year = 2021 THEN a.product_code END) AS product_count_2021,
    (COUNT(DISTINCT CASE WHEN b.fiscal_year = 2021 THEN a.product_code END) - 
     COUNT(DISTINCT CASE WHEN b.fiscal_year = 2020 THEN a.product_code END)) AS difference
FROM dim_product AS a
JOIN fact_sales_monthly AS b ON a.product_code = b.product_code
GROUP BY a.segment
ORDER BY difference DESC;

-- 5. Get the products with the highest and lowest manufacturing costs.
CREATE VIEW question_5 AS
SELECT 
    dp.product_code, 
    dp.product, 
    mc.manufacturing_cost
FROM fact_manufacturing_cost mc
JOIN dim_product dp ON dp.product_code = mc.product_code
WHERE mc.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)
UNION
SELECT 
    dp.product_code, 
    dp.product, 
    mc.manufacturing_cost
FROM fact_manufacturing_cost mc
JOIN dim_product dp ON dp.product_code = mc.product_code
WHERE mc.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost);

-- 6. Top 5 customers with the highest average pre-invoice discount in 2021 for the Indian market.
CREATE VIEW question_6 AS
WITH cte1 AS (
    SELECT 
        a.customer_code,
        a.customer,
        a.market,
        b.fiscal_year,
        b.pre_invoice_discount_pct
    FROM dim_customer AS a
    JOIN fact_pre_invoice_deductions AS b ON a.customer_code = b.customer_code
),
cte2 AS (
    SELECT 
        customer_code, 
        customer, 
        market, 
        AVG(pre_invoice_discount_pct) AS average_discount
    FROM cte1
    WHERE fiscal_year = 2021 
      AND LOWER(market) = 'india'
    GROUP BY customer_code, customer, market
)
SELECT 
    customer_code, 
    customer, 
    ROUND(average_discount * 100, 2) AS average_discount
FROM cte2
ORDER BY average_discount DESC
LIMIT 5;

-- 7. Monthly gross sales for "Atliq Exclusive".
CREATE VIEW question_7 AS
WITH cte1 AS (
    SELECT 
        a.customer_code, 
        a.customer, 
        b.date, 
        b.product_code, 
        b.fiscal_year, 
        b.sold_quantity
    FROM dim_customer AS a
    JOIN fact_sales_monthly AS b ON a.customer_code = b.customer_code
    WHERE customer = 'Atliq Exclusive'
),
cte2 AS (
    SELECT 
        a.customer_code, 
        a.customer, 
        a.date, 
        a.product_code, 
        a.fiscal_year, 
        a.sold_quantity, 
        b.gross_price
    FROM cte1 AS a
    JOIN fact_gross_price AS b ON a.product_code = b.product_code
)
SELECT 
    MONTHNAME(date) AS month, 
    fiscal_year, 
    SUM(gross_price * sold_quantity) AS total_gross_sales
FROM cte2
GROUP BY month, fiscal_year;

-- 8. Quarter with maximum total sold quantity in 2020.
CREATE VIEW question_8 AS
SELECT 
    CASE
        WHEN MONTH(date) BETWEEN 1 AND 3 THEN 'Q1'
        WHEN MONTH(date) BETWEEN 4 AND 6 THEN 'Q2'
        WHEN MONTH(date) BETWEEN 7 AND 9 THEN 'Q3'
        ELSE 'Q4'
    END AS quarter,
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY quarter
ORDER BY total_sold_quantity DESC;

-- 9. Channel with the highest gross sales in 2021 and its percentage contribution.
CREATE VIEW question_9 AS
WITH cte1 AS (
    SELECT 
        a.channel, 
        b.product_code, 
        b.fiscal_year, 
        b.sold_quantity
    FROM dim_customer AS a
    JOIN fact_sales_monthly AS b ON a.customer_code = b.customer_code
),
cte2 AS (
    SELECT 
        a.channel, 
        a.product_code, 
        a.fiscal_year, 
        a.sold_quantity, 
        b.gross_price
    FROM cte1 AS a
    JOIN fact_gross_price AS b ON a.product_code = b.product_code
),
cte3 AS (
    SELECT 
        channel, 
        ROUND(SUM(sold_quantity * gross_price) / 1000000, 1) AS gross_sales_mln
    FROM cte2
    WHERE fiscal_year = 2021
    GROUP BY channel
)
SELECT 
    channel, 
    gross_sales_mln, 
    ROUND((gross_sales_mln / total_sales) * 100, 2) AS percentage_contribution
FROM cte3, 
(SELECT SUM(gross_sales_mln) AS total_sales FROM cte3) AS total
ORDER BY gross_sales_mln DESC;

-- 10. Top 3 products by sold quantity in each division in 2021.
CREATE VIEW question_10 AS
WITH cte1 AS (
    SELECT 
        a.division, 
        a.product_code, 
        a.product, 
        SUM(b.sold_quantity) AS total_sold_quantity
    FROM dim_product AS a
    JOIN fact_sales_monthly AS b ON a.product_code = b.product_code
    WHERE fiscal_year = 2021
    GROUP BY a.division, a.product_code, a.product
)
SELECT 
    division, 
    product_code, 
    product, 
    total_sold_quantity, 
    RANK() OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order
FROM cte1
WHERE rank_order <= 3
ORDER BY division, rank_order;
