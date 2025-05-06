--TASK 1
--Create a query to produce a sales report highlighting the top customers with the highest sales across different sales channels. This report should list the top 5 customers for each channel. Additionally, calculate a key performance indicator (KPI) called 'sales_percentage,' which represents the percentage of a customer's sales relative to the total sales within their respective channel.
--I choose row_number to rank customers per channel and limit to the top 5 per channel.  Window functions are perfect for ranking rows within groups without collapsing them,
--which let me rank customers by total sales while still showing each customer's full info.
--This way, I could easily filter for the top 5 using a simple condition.
SELECT
  ranked.channel_desc,
  ranked.cust_last_name,
  ranked.cust_first_name,
   -- Fprmats sales as decimal
  ROUND(ranked.amount_sold, 2)::DECIMAL(12,2) AS amount_sold,

  -- converts sales share to percentage
  ROUND((ranked.amount_sold/ ranked.channel_amount_sold) * 100, 4)::DECIMAL(7,4) AS sales_percentage

  FROM (
  SELECT 
    chan.channel_desc,
    cust.cust_first_name,
    cust.cust_last_name,
    SUM(sales.amount_sold) AS amount_sold, -- calculates total sales per customer
    SUM(SUM(sales.amount_sold)) OVER (PARTITION BY chan.channel_id) AS channel_amount_sold, --total sales for the whole channel, using a window aggregate.
    ROW_NUMBER() OVER ( 
      PARTITION BY chan.channel_id
      ORDER BY SUM(sales.amount_sold) DESC
    ) AS row_num --ranking of customers within each channel by their total sales DESC order
  FROM sh.customers AS cust
  INNER JOIN sh.sales sales ON cust.cust_id = sales.cust_id
  INNER JOIN sh.channels chan ON sales.channel_id = chan.channel_id
  GROUP BY chan.channel_id, sales.cust_id, cust.cust_first_name, cust.cust_last_name --- I use channel_id  and cust_id is actually used to group. first_name and last_name group to be choosen is select
) ranked 
WHERE ranked.row_num <= 5 -- filters 5 customers
ORDER BY ranked.channel_desc, ranked.amount_sold DESC; -- sortes output


--TASK 2--
-- I chose to use the `crosstab` function from the `tablefunc` extension to transform row-based quarterly data 
-- Crosstab is ideal when we have a predictable set of values like Q1, Q2, Q3, Q4. and it avoid complex manual aggregation using CASE statements. it simplifies calculating year sum for each products
-- The use of `COALESCE` ensures that missing quarterly data doesn't break the report and lets us display blanks.
CREATE EXTENSION IF NOT EXISTS tablefunc;
SELECT  
  prod_name,

  -- Replace NULLs with blank strings for display
  COALESCE(Q1::TEXT, '') AS Q1,
  COALESCE(Q2::TEXT, '') AS Q2,
  COALESCE(Q3::TEXT, '') AS Q3,
  COALESCE(Q4::TEXT, '') AS Q4,

  -- Total across all quarters, replace nulls with 0 for calculation
  ROUND(
    COALESCE(Q1, 0) + COALESCE(Q2, 0) + COALESCE(Q3, 0) + COALESCE(Q4, 0), 
    2
  ) AS year_sum

FROM (
  SELECT *  
  FROM crosstab(
    $$
    SELECT 
      prod.prod_name,
      times.calendar_quarter_number::TEXT AS quarter,
      ROUND(SUM(sales.amount_sold), 2)  -- Aggregate sales per product per quarter
    FROM sh.products AS prod
    INNER JOIN sh.sales AS sales ON prod.prod_id = sales.prod_id
    INNER JOIN sh.times AS times ON sales.time_id = times.time_id
    INNER JOIN sh.customers AS cust ON sales.cust_id = cust.cust_id
    INNER JOIN sh.countries AS countr ON cust.country_id = countr.country_id
    WHERE prod.prod_category = 'Photo'
      AND times.calendar_year = 2000
      AND countr.country_region = 'Asia' --filters
    GROUP BY prod.prod_name, times.calendar_quarter_number
    ORDER BY prod.prod_name, quarter
    $$,
    $$ SELECT unnest(ARRAY['1','2','3','4']) $$
  ) AS ct (
-- Define column structure for the crosstab output
    prod_name TEXT,
    Q1 NUMERIC(12,2),
    Q2 NUMERIC(12,2),
    Q3 NUMERIC(12,2),
    Q4 NUMERIC(12,2)
  )
) AS crosstab_with_total
ORDER BY year_sum DESC;



--TASK 3
-- using ctes allows step-by-step filtering:  first aggregating sales, then ranking, then filtering consistent top customers.
-- using rank function to rank customers by sales per channel and year.
--Finally, I joined the qualified list back to the sales data to calculate their total sales within that channel.

WITH sales_per_customer_year_channel AS (
  -- Pre-aggregate sales per customer per year per channel
  SELECT
    s.cust_id,
    ch.channel_id,
    ch.channel_desc,
    t.calendar_year,
    SUM(s.amount_sold) AS amount_sold
  FROM sh.sales AS s
  INNER JOIN sh.times t ON s.time_id = t.time_id
  INNER JOIN sh.channels ch ON s.channel_id = ch.channel_id
  WHERE t.calendar_year IN (1998, 1999, 2001)
  GROUP BY s.cust_id, ch.channel_id, ch.channel_desc, t.calendar_year
),

ranked_sales AS (
  -- Rank customers per channel per year based on pre-aggregated totals
  SELECT
    *,
    RANK() OVER (
      PARTITION BY channel_id, calendar_year
      ORDER BY amount_sold DESC
    ) AS sales_rank
  FROM sales_per_customer_year_channel
),

top_300_per_year AS (
  SELECT *
  FROM ranked_sales
  WHERE sales_rank <= 300
),

qualified_customers AS (
  -- Only those who ranked in top 300 in all 3 years for a given channel
  SELECT
    cust_id,
    channel_id,
    channel_desc
  FROM top_300_per_year
  GROUP BY cust_id, channel_id, channel_desc
  HAVING COUNT(DISTINCT calendar_year) = 3
),

final_sales AS (
  -- Sum full sales (only for filtered customers, by channel)
  SELECT
    q.channel_desc,
    s.cust_id,
    c.cust_last_name,
	c.cust_first_name,
    ROUND(SUM(s.amount_sold), 2) AS amount_sold
  FROM qualified_customers q
  INNER JOIN sh.sales s ON q.cust_id = s.cust_id AND q.channel_id = s.channel_id
  INNER JOIN sh.customers c ON c.cust_id = s.cust_id
  INNER JOIN sh.times t ON s.time_id = t.time_id
  WHERE t.calendar_year IN (1998, 1999, 2001)
  GROUP BY q.channel_desc, s.cust_id, c.cust_first_name, c.cust_last_name
)

SELECT *
FROM final_sales
ORDER BY amount_sold DESC;


----Task 4
--I used a window function to calculate regional sales without collapsing category-month combinations,
--so I could later pivot the results cleanly into separate columns for each region.
--This approach kept the structure flexible while meeting the task's format and aggregation requirements without using window frames.

WITH sales_with_regions AS (
    SELECT
        t.calendar_month_desc,
        p.prod_category,
        co.country_region,
        s.amount_sold
    FROM sh.sales s
    INNER JOIN sh.times t ON s.time_id = t.time_id
    INNER JOIN sh.products p ON s.prod_id = p.prod_id
    INNER JOIN sh.customers c ON s.cust_id = c.cust_id
    INNER JOIN sh.countries co ON c.country_id = co.country_id
    WHERE t.calendar_month_desc IN ('2000-01', '2000-02', '2000-03')
      AND co.country_region IN ('Europe', 'Americas')
),
ranked_sales AS (
    SELECT
        calendar_month_desc,
        prod_category,
        country_region,
        SUM(amount_sold) OVER (
            PARTITION BY calendar_month_desc, prod_category, country_region
        ) AS regional_sales
    FROM sales_with_regions
),
deduplicated AS (
    SELECT DISTINCT
        calendar_month_desc,
        prod_category,
        country_region,
        regional_sales
    FROM ranked_sales
)
SELECT
    calendar_month_desc,
    prod_category,
    ROUND(MAX(CASE WHEN country_region = 'Americas' THEN regional_sales END), 0) AS "Americas SALES",
    ROUND(MAX(CASE WHEN country_region = 'Europe' THEN regional_sales END), 0) AS "Europe SALES"
FROM deduplicated
GROUP BY calendar_month_desc, prod_category
ORDER BY calendar_month_desc, prod_category;



