--Task 1
--Create a query for analyzing the annual sales data for the years 1999 to 2001, focusing on different sales channels and regions: 'Americas,' 'Asia,' and 'Europe.' 
WITH
	mainquery AS (
		-- Total sales grouped by region, year, and sales channel
		SELECT
			countries.country_region,
			times.calendar_year,
			channels.channel_desc,
			SUM(sales.amount_sold) AS amount_sold
		FROM
			sh.sales AS sales
			INNER JOIN sh.channels AS channels ON sales.channel_id=channels.channel_id
			INNER JOIN sh.customers AS customers ON sales.cust_id=customers.cust_id
			INNER JOIN sh.countries AS countries ON customers.country_id=countries.country_id
			INNER JOIN sh.times AS times ON sales.time_id=times.time_id
		WHERE
			times.calendar_year BETWEEN 1998 AND 2001  AND
			countries.country_region IN ('Americas', 'Asia', 'Europe')
		GROUP BY
			countries.country_region,
			times.calendar_year,
			channels.channel_desc
	),
	with_pct AS (
		-- % of total region-year sales per channel
		SELECT
			*,
			ROUND(
				amount_sold*100.0/SUM(amount_sold) OVER (
					PARTITION BY
						country_region,
						calendar_year ROWS BETWEEN unbounded preceding AND
						unbounded following
				),
				2
			) AS bychannel
		FROM
			mainquery
	),
	with_lag AS (
		-- % from previous year per channel and region
		SELECT
			*,
			ROUND(
				LAG(bychannel) OVER (
					PARTITION BY
						country_region,
						channel_desc
					ORDER BY
						calendar_year ROWS BETWEEN 1 preceding AND
						1 preceding
				),
				2
			) AS previousperiod
		FROM
			with_pct
	),
	diff AS (
		-- Difference in % compared to previous year
		SELECT
			*,
			bychannel-previousperiod AS diff
		FROM
			with_lag
	)
	-- Final result
SELECT
	country_region,
	calendar_year,
	channel_desc,
	amount_sold AS "amount_sold",
	bychannel||'%' AS "% BY CHANNELS",
	previousperiod||'%' AS "% PREVIOUS PERIOD",
	ROUND(diff, 2)||'%' AS diff
FROM
	diff
WHERE
	calendar_year BETWEEN 1999 AND 2001
ORDER BY
	country_region,
	calendar_year,
	channel_desc;

--TASK2
WITH
	daily_sales AS (
		-- Get daily sales for each day in weeks 49 to 51 of 1999
		SELECT
			t.time_id AS calendar_date,
			t.day_name,
			t.calendar_week_number,
			t.calendar_year,
			SUM(s.amount_sold) AS amount_sold
		FROM
			sh.sales s
			INNER JOIN sh.times t ON s.time_id=t.time_id
		WHERE
			t.calendar_year=1999 AND
			t.calendar_week_number BETWEEN 49 AND 51
		GROUP BY
			t.time_id,
			t.day_name,
			t.calendar_week_number,
			t.calendar_year
	),
	with_cumsum AS (
		-- Running total per week (resets each week), ordered by date
		SELECT
			*,
			SUM(amount_sold) OVER (
				PARTITION BY
					calendar_week_number
				ORDER BY
					calendar_date ROWS BETWEEN unbounded preceding AND
					current ROW
			) AS cum_sum
		FROM
			daily_sales
	),
	with_centered_avg AS (
		-- 3-day centered average: picks 3 days around each row depending on the day of the week
		SELECT
			*,
			CASE
				WHEN day_name='Monday' THEN
				-- Grab 2 previous + 1 next (since Monday is early in the week)
				ROUND(
					AVG(amount_sold) OVER (
						ORDER BY
							calendar_date ROWS BETWEEN 2 preceding AND
							1 following
					),
					2
				)
				WHEN day_name='Friday' THEN
				-- Grab 1 previous + 2 next (since Friday is toward the end)
				ROUND(
					AVG(amount_sold) OVER (
						ORDER BY
							calendar_date ROWS BETWEEN 1 preceding AND
							2 following
					),
					2
				)
				ELSE
				-- Regular 1 day before and after
				ROUND(
					AVG(amount_sold) OVER (
						ORDER BY
							calendar_date ROWS BETWEEN 1 preceding AND
							1 following
					),
					2
				)
			END AS centered_3_day_avg
		FROM
			with_cumsum
	)
	--Final Output
SELECT
	calendar_week_number,
	calendar_date,
	day_name,
	amount_sold AS "sales",
	cum_sum,
	centered_3_day_avg
FROM
	with_centered_avg
ORDER BY
	calendar_date;

--TASK3
SELECT
	s.time_id,
	s.amount_sold,
	ROUND(
		AVG(s.amount_sold) OVER (
			ORDER BY
				s.time_id ROWS BETWEEN 2 preceding AND
				current ROW
		),
		2
	) AS moving_avg_3_rows
FROM
	sh.sales s
	INNER JOIN sh.times t ON s.time_id=t.time_id
WHERE
	t.calendar_year=1999
ORDER BY
	s.time_id;

--ROWS counts physical rows. This is ideal for a 3-day sliding average, regardless of actual date gaps. If 3 rows = Dec 1, Dec 3, Dec 10 → it still averages those. Use it when you want N-row logic regardless of date continuity.
SELECT
	s.time_id,
	s.amount_sold,
	SUM(s.amount_sold) OVER (
		ORDER BY
			s.time_id RANGE BETWEEN INTERVAL '6 days' preceding AND
			current ROW
	) AS rolling_7_day_sum
FROM
	sh.sales s
	JOIN sh.times t ON s.time_id=t.time_id
WHERE
	t.calendar_year=1999
ORDER BY
	s.time_id;

--RANGE expands to all rows within a logical value range — here: all sales within the past 7 days (including current). It handles date continuity, not row count. This is best for calendar-based logic (like week-over-week comparisons or date ranges).
SELECT
	s.channel_id,
	s.amount_sold,
	RANK() OVER (
		PARTITION BY
			s.channel_id
		ORDER BY
			s.amount_sold
	) AS rank_in_channel,
	SUM(s.amount_sold) OVER (
		PARTITION BY
			s.channel_id
		ORDER BY
			s.amount_sold GROUPS BETWEEN 1 preceding AND
			1 following
	) AS sum_over_rank_groups
FROM
	sh.sales s
WHERE
	s.channel_id IN (2, 3)
ORDER BY
	s.channel_id,
	s.amount_sold;

--GROUPS operates on peer groups: rows with the same ORDER BY value. This is great for ranked/tied values — e.g., "get total sales in thecurrent and neighboring rank groups". Unlike ROWS, GROUPS won't slice inside ties.
