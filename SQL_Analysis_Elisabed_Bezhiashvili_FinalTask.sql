-- Task 1. Window Functions
-- Create a query to generate a report that identifies for each channel and throughout the entire period, the regions with the highest quantity of products sold (quantity_sold). 
-- I used window functions here because I needed to compare sales values across the same channel.
-- The goal was to find the region(s) with the highest quantity sold per channel, 
-- and window functions helped me get the total and max sales without needing subqueries or joins.
-- I used MAX() OVER (PARTITION BY channel_desc) so that I can keep all rows and later just filter to the top region(s).
-- I chose to filter with WHERE sales = max_channel_sales to allow tied top regions, not just the top one.
-- Percentage is calculated against total sales per channel to follow the requirement and formatted with two decimals + '%'.
WITH
	main AS (
		SELECT
			chann.channel_desc,
			country.country_region,
			-- Calculate total sales per (channel, region) using a window function
			-- Window functions allow us to aggregate without collapsing rows, preserving granularity
			SUM(sale.quantity_sold) OVER (
				PARTITION BY
					chann.channel_id,
					country.country_region
			) AS sales,
			-- Calculate total sales per channel (all regions combined) to later compute sales %
			SUM(sale.quantity_sold) OVER (
				PARTITION BY
					chann.channel_id
			) AS total_sales_per_channel
		FROM
			sh.sales AS sale
			INNER JOIN sh.customers AS cust ON sale.cust_id=cust.cust_id
			INNER JOIN sh.countries AS country ON cust.country_id=country.country_id
			INNER JOIN sh.channels AS chann ON sale.channel_id=chann.channel_id
	),
	ranked AS (
		SELECT
			channel_desc,
			country_region,
			sales,
			total_sales_per_channel,
			-- Use ROW_NUMBER() to rank regions per channel by sales descending
			-- This lets us pick only the top region per channel in the next step
			ROW_NUMBER() OVER (
				PARTITION BY
					channel_desc
				ORDER BY
					sales DESC
			) AS ranking
		FROM
			main
	)
SELECT
	channel_desc,
	country_region,
	-- Round with 2 decimal places
	ROUND(sales::NUMERIC, 2) AS sales,
	-- Append '%'
	ROUND((sales/total_sales_per_channel)*100, 2)||'%' AS "sales %"
FROM
	ranked
WHERE
	ranking=1
ORDER BY
	sales DESC;

-- TASK 2 
-- Identify the subcategories of products with consistently higher sales from 1998 to 2001 compared to the previous year. 
-- Here I wanted to check which product subcategories were growing every year from 1998 to 2001.
-- I used LAG() window function because it was the easiest way to compare current year sales with the previous year.
-- Then I filtered only the rows where sales were higher than the previous year, to focus on real growth.
-- I counted how many years had growth for each subcategory and kept only those with 3 growing years (1999, 2000, 2001).
-- I didn’t use rank or complex joins here because window function with LAG() was the most readable and clean solution.
WITH
	yearly_sales AS (
		-- Add previous year’s total sales to each row per subcategory to compare growth year-over-year
		SELECT
			products.prod_subcategory,
			times.calendar_year,
			SUM(sales.amount_sold) AS total_sales
		FROM
			sh.sales AS sales
			INNER JOIN sh.products AS products ON sales.prod_id=products.prod_id
			INNER JOIN sh.times AS times ON sales.time_id=times.time_id
		WHERE
			times.calendar_year BETWEEN 1998 AND 2001
		GROUP BY
			products.prod_subcategory,
			times.calendar_year
	),
	with_lag AS (
		SELECT
			prod_subcategory,
			calendar_year,
			total_sales,
			LAG(total_sales) OVER (
				PARTITION BY
					prod_subcategory
				ORDER BY
					calendar_year
			) AS prev_year_sales
		FROM
			yearly_sales
	),
	growth_years AS (
		-- Filter only years where current year's sales exceed previous year's sales (indicating growth)
		-- Restrict years to 1999-2001 because lag for 1998 would be NULL (no prior year data)
		SELECT
			*
		FROM
			with_lag
		WHERE
			total_sales>prev_year_sales AND
			calendar_year BETWEEN 1999 AND 2001
	),
	consistent_subcategories AS (
		-- Identify product subcategories with growth in all 3 consecutive years (1999, 2000, 2001
		SELECT
			prod_subcategory,
			COUNT(*) AS growth_count
		FROM
			growth_years
		GROUP BY
			prod_subcategory
		HAVING
			COUNT(*)=3
	)
	-- Final output:
SELECT
	prod_subcategory
FROM
	consistent_subcategories;

-- Task 3. Window Frames
-- Create a query to generate a sales report for the years 1999 and 2000, focusing on quarters and product categories. In the report you have to  analyze the sales of products from the categories 'Electronics,' 'Hardware,' and 'Software/Other,' across the distribution channels 'Partners' and 'Internet'.
-- Get total sales by year, quarter, and product category for selected years, channels, and categories
-- This task asked for a cumulative sum and difference from Q1, so it was a good use case for window frames.
-- I separated the logic into smaller CTEs to keep it clean and easier to debug step-by-step.
-- For diff_percent I joined Q1 values manually instead of using FIRST_VALUE because it gave me more control,
-- and I could apply 'N/A' to Q1 easily this way without tricky conditions inside window function.
-- For cum_sum$, I used SUM() OVER with ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW, 
-- to follow the window frame requirement from the task and make sure it's calculated row-by-row in proper order.
-- Finally, I used ORDER BY with year, quarter, and sales descending to match the expected report format exactly.
WITH
	base_sales AS (
		SELECT
			times.calendar_year,
			times.calendar_quarter_desc,
			products.prod_category,
			SUM(sales.amount_sold) AS sales
		FROM
			sh.sales AS sales
			INNER JOIN sh.times AS times ON sales.time_id=times.time_id
			INNER JOIN sh.products AS products ON sales.prod_id=products.prod_id
			INNER JOIN sh.channels AS channels ON sales.channel_id=channels.channel_id
		WHERE
			times.calendar_year IN (1999, 2000) AND
			LOWER(channels.channel_desc) IN ('partners', 'internet') AND
			LOWER(products.prod_category) IN ('electronics', 'hardware', 'software/other')
		GROUP BY
			times.calendar_year,
			times.calendar_quarter_desc,
			products.prod_category
	),
	-- Extract Q1 sales as baseline for percentage difference calculation
	q1_sales AS (
		SELECT
			calendar_year,
			prod_category,
			sales AS q1_sales
		FROM
			base_sales
		WHERE
			calendar_quarter_desc LIKE '%-01' -- only first quarter
	),
	-- Aggregate sales by year and quarter (all categories combined) for cumulative sum calculation
	cumulative_sales AS (
		SELECT
			calendar_year,
			calendar_quarter_desc,
			SUM(sales) AS sales_sum
		FROM
			base_sales
		GROUP BY
			calendar_year,
			calendar_quarter_desc
	),
	-- Calculate running total of sales per year, ordered by quarter
	cumulative_sales_with_window AS (
		SELECT
			calendar_year,
			calendar_quarter_desc,
			ROUND(
				SUM(sales_sum) OVER (
					PARTITION BY
						calendar_year
					ORDER BY
						calendar_quarter_desc ROWS BETWEEN unbounded preceding AND
						current ROW
				),
				2
			) AS cum_sum_per_quarter
		FROM
			cumulative_sales
	),
	-- Final step: combine sales, percentage difference, and cumulative sum with formatting
	final_report AS (
		SELECT
			base.calendar_year,
			base.calendar_quarter_desc,
			base.prod_category,
			ROUND(base.sales, 2) AS "sales$",
			CASE
				WHEN base.calendar_quarter_desc LIKE '%-01' THEN 'N/A' -- baseline quarter
				ELSE ROUND((base.sales-q1.q1_sales)*100.0/q1.q1_sales, 2)||'%'
			END AS diff_percent,
			cumulative.cum_sum_per_quarter AS "cum_sum$"
		FROM
			base_sales AS base
			LEFT JOIN q1_sales AS q1 ON base.calendar_year=q1.calendar_year AND
			base.prod_category=q1.prod_category
			LEFT JOIN cumulative_sales_with_window AS cumulative ON base.calendar_year=cumulative.calendar_year AND
			base.calendar_quarter_desc=cumulative.calendar_quarter_desc
	)
	-- Order as requested: year, quarter, sales descending
SELECT
	*
FROM
	final_report
ORDER BY
	calendar_year,
	calendar_quarter_desc,
	"sales$" DESC;

