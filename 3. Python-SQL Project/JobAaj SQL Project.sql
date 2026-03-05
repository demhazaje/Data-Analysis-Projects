-- Advanced Problem 1: Moving average of order values for each customer
WITH CustomerOrders AS (
    SELECT 
        o.customer_id, 
        o.order_id, 
        o.order_purchase_timestamp,
        SUM(p.payment_value) AS order_value
    FROM orders o
    JOIN payments p ON o.order_id = p.order_id
    GROUP BY o.customer_id, o.order_id, o.order_purchase_timestamp
)
SELECT 
    customer_id,
    order_id,
    order_purchase_timestamp,
    ROUND(order_value, 2) AS order_value,
    ROUND(AVG(order_value) OVER (
        PARTITION BY customer_id 
        ORDER BY order_purchase_timestamp 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_order_value
FROM CustomerOrders
ORDER BY customer_id, order_purchase_timestamp;


-- Advanced Problem 2: Cumulative sales per month for each year
WITH MonthlySales AS (
    SELECT 
        YEAR(o.order_purchase_timestamp) AS order_year,
        MONTH(o.order_purchase_timestamp) AS order_month,
        SUM(p.payment_value) AS total_sales
    FROM orders o
    JOIN payments p ON o.order_id = p.order_id
    GROUP BY order_year, order_month
)
SELECT 
    order_year,
    order_month,
    ROUND(total_sales, 2) AS monthly_sales,
    ROUND(SUM(total_sales) OVER (
        PARTITION BY order_year 
        ORDER BY order_month
    ), 2) AS cumulative_sales
FROM MonthlySales
ORDER BY order_year, order_month;



-- Advanced Problem 3: Year-over-year growth rate of total sales
WITH YearlySales AS (
    SELECT 
        YEAR(o.order_purchase_timestamp) AS order_year,
        SUM(p.payment_value) AS total_sales
    FROM orders o
    JOIN payments p ON o.order_id = p.order_id
    GROUP BY order_year
)
SELECT 
    order_year,
    ROUND(total_sales, 2) AS current_year_sales,
    ROUND(LAG(total_sales) OVER (ORDER BY order_year), 2) AS previous_year_sales,
    ROUND(
        ((total_sales - LAG(total_sales) OVER (ORDER BY order_year)) / 
        LAG(total_sales) OVER (ORDER BY order_year)) * 100
    , 2) AS yoy_growth_percentage
FROM YearlySales;



-- Advanced Problem 4: Customer retention rate (repeat purchase within 6 months)
WITH FirstPurchases AS (
    -- Step 1: Find the very first purchase date for each unique person
    SELECT 
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),
SubsequentPurchases AS (
    -- Step 2: Find people who bought again within 6 months of that first date
    SELECT DISTINCT fp.customer_unique_id
    FROM FirstPurchases fp
    JOIN customers c ON fp.customer_unique_id = c.customer_unique_id
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_purchase_timestamp > fp.first_purchase_date
      AND o.order_purchase_timestamp <= DATE_ADD(fp.first_purchase_date, INTERVAL 6 MONTH)
)
-- Step 3: Calculate the final percentage
SELECT 
    (SELECT COUNT(*) FROM FirstPurchases) AS total_customers,
    (SELECT COUNT(*) FROM SubsequentPurchases) AS retained_customers,
    ROUND(
        ((SELECT COUNT(*) FROM SubsequentPurchases) / (SELECT COUNT(*) FROM FirstPurchases)) * 100
    , 2) AS retention_rate_percentage;
    
    
    -- Advanced Problem 5: Top 3 customers who spent the most money in each year
WITH CustomerYearlySpend AS (
    -- Step 1: Calculate total spent per person, per year
    SELECT 
        YEAR(o.order_purchase_timestamp) AS order_year,
        c.customer_unique_id,
        SUM(p.payment_value) AS total_spent
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN payments p ON o.order_id = p.order_id
    GROUP BY order_year, c.customer_unique_id
),
RankedCustomers AS (
    -- Step 2: Rank them within each year
    SELECT 
        order_year,
        customer_unique_id,
        total_spent,
        DENSE_RANK() OVER (PARTITION BY order_year ORDER BY total_spent DESC) AS spend_rank
    FROM CustomerYearlySpend
)
-- Step 3: Filter for the top 3
SELECT 
    order_year,
    spend_rank,
    customer_unique_id,
    ROUND(total_spent, 2) AS total_spent
FROM RankedCustomers
WHERE spend_rank <= 3
ORDER BY order_year, spend_rank;
