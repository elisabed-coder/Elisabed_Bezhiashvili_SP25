-- TASK 1
--The DROP FUNCTION statement is used to delete an existing function. The IF EXISTS clause makes sure that the function is only dropped if it actually exists.
DROP VIEW IF EXISTS public.sales_revenue_by_category_qtr;
-- also using create or replace-The CREATE OR REPLACE FUNCTION ensures that if the function doesn't exist, it will be created. If it already exists, it will be replaced with the updated definition, which includes any new logic, parameters, or return types.
--By using both, you ensure that the function is always up to date and that no errors occur due to an outdated or conflicting function definition. Sometimes its not possible to update view with create or replace statement and thats why i use both of them.


CREATE OR REPLACE VIEW public.sales_revenue_by_category_qtr AS
WITH
	current_qtr AS (
		SELECT
			--extract current quarter and year from current_Date
			EXTRACT(YEAR FROM CURRENT_DATE)::INT AS year,
			EXTRACT(QUARTER FROM CURRENT_DATE)::INT AS quarter
			-- 2017 AS YEAR, -- Fixed year
			-- EXTRACT(
			-- 	QUARTER
			-- 	FROM
			-- 		CURRENT_DATE
			-- )::INT AS quarter -- Still use current quarter
	),
	quarter_range AS (
	--calculate the exact start and end dates of quarter
		SELECT
			MAKE_DATE(YEAR, (quarter - 1)*3+1, 1) AS start_date,
			MAKE_DATE(YEAR, (quarter - 1)*3+1, 1)+INTERVAL '3 months' AS end_date
		FROM
			current_qtr
	)
SELECT
	cat.name AS category_name,
	SUM(pay.amount) AS total_amount
FROM
	public.payment AS pay
	INNER JOIN public.rental AS rent ON pay.rental_id=rent.rental_id
	INNER JOIN public.inventory AS inv ON rent.inventory_id=inv.inventory_id
	INNER JOIN public.film AS film ON inv.film_id=film.film_id
	INNER JOIN public.film_category fc ON fc.film_id=film.film_id
	INNER JOIN public.category AS cat ON fc.category_id=cat.category_id,
	quarter_range AS q
WHERE
	pay.payment_date>=q.start_date AND
	pay.payment_date<q.end_date
GROUP BY
	cat.category_id,
	cat.name
HAVING
	SUM(pay.amount)>0
ORDER BY
	total_amount DESC;
SELECT
	*
FROM
	sales_revenue_by_category_qtr;

	
--Create a query language function called 'get_sales_revenue_by_category_qtr' that accepts one parameter representing the current quarter and year and returns the same result as the 'sales_revenue_by_category_qtr' view.


DROP FUNCTION IF EXISTS public.get_sales_revenue_by_category_qtr (TEXT);

CREATE OR REPLACE FUNCTION public.get_sales_revenue_by_category_qtr (p_qtr TEXT) RETURNS TABLE (category_name TEXT, total_amount NUMERIC) AS $$
DECLARE
    p_year INT;
    p_quarter INT;
    start_date DATE;
    end_date DATE;
BEGIN
    -- Extract year and quarter from the input string (e.g., '2024Q2')
    p_year := SUBSTRING(p_qtr FROM 1 FOR 4)::INT;
    p_quarter := SUBSTRING(p_qtr FROM 6 FOR 1)::INT;

    -- Validate year and quarter
    IF p_year < 1900 OR p_year > EXTRACT(YEAR FROM CURRENT_DATE)::INT + 10 THEN
        RAISE EXCEPTION 'Invalid year: %, must be reasonable', p_year;
    END IF;

    IF p_quarter NOT BETWEEN 1 AND 4 THEN
        RAISE EXCEPTION 'Invalid quarter: %, must be between 1 and 4', p_quarter;
    END IF;

    -- Compute quarter start and end dates
    start_date := MAKE_DATE(p_year, (p_quarter - 1) * 3 + 1, 1);
    end_date := start_date + INTERVAL '3 months';

    -- Return category sales revenue for the given quarter
    RETURN QUERY
    SELECT 	
        cat.name AS category_name,
        SUM(pay.amount) AS total_amount
    FROM public.payment AS pay
        INNER JOIN public.rental AS rent ON pay.rental_id = rent.rental_id
        INNER JOIN public.inventory AS inv ON rent.inventory_id = inv.inventory_id
        INNER JOIN public.film AS film ON inv.film_id = film.film_id
        INNER JOIN public.film_category AS fc ON fc.film_id = film.film_id
        INNER JOIN public.category AS cat ON fc.category_id = cat.category_id
    WHERE
        pay.payment_date >= start_date AND pay.payment_date < end_date
	GROUP BY cat.category_id, cat.name
    HAVING SUM(pay.amount) > 0
	ORDER BY total_amount DESC;
END;
$$ LANGUAGE plpgsql;

-- examples
SELECT
	*
FROM
	public.get_sales_revenue_by_category_qtr ('2017Q2');

	
SELECT
	*
FROM
	get_sales_revenue_by_category_qtr (
		EXTRACT(
			YEAR
			FROM
				CURRENT_DATE
		)::TEXT||'Q'||EXTRACT(
			QUARTER
			FROM
				CURRENT_DATE
		)::TEXT
	);

--Task 3. Create procedure language functions
-- New function to handle an array of countries
DROP FUNCTION IF EXISTS public.most_popular_films_by_countries(TEXT[]);

CREATE OR REPLACE FUNCTION public.most_popular_films_by_countries(p_countries TEXT[]) RETURNS TABLE (
	country_name TEXT,
	film TEXT,
	rating TEXT,
	"language" TEXT,
	"length" INT,
	release_year INT
) LANGUAGE plpgsql AS $$
BEGIN
    IF p_countries IS NULL OR array_length(p_countries, 1) = 0 THEN
        RAISE EXCEPTION 'Country list cannot be null or empty.';
    END IF;

    RETURN QUERY
    WITH ranked_films AS (
        SELECT
            ctr.country AS country,
            film.title,
            film.rating::TEXT AS rating,
            lang.name::TEXT AS language,
            film.length::INT AS length,
            film.release_year::INT AS release_year,
            COUNT(*) AS rental_count,
            ROW_NUMBER() OVER (
                PARTITION BY ctr.country
                ORDER BY COUNT(*) DESC
            ) AS rank
        FROM customer AS  cus
            INNER JOIN public.address AS addr ON cus.address_id = addr.address_id
            INNER JOIN public.city AS ct ON addr.city_id = ct.city_id
            INNER JOIN public.country AS ctr ON ct.country_id = ctr.country_id
            INNER JOIN public.rental AS rent ON cus.customer_id = rent.customer_id
            INNER JOIN public.inventory AS inv ON rent.inventory_id = inv.inventory_id
            INNER JOIN public.film ON inv.film_id = film.film_id
            INNER JOIN language AS lang ON film.language_id = lang.language_id
        WHERE UPPER(ctr.country) = ANY (SELECT UPPER(c) FROM unnest(p_countries) AS c)
        GROUP BY 
            ctr.country, film.title, film.film_id, ctr.country_id, lang.name, lang.language_id
    )
    SELECT 
        rf.country AS country_name,
        rf.title AS film,
        rf.rating,
        rf.language,
        rf.length,
        rf.release_year
    FROM ranked_films rf
    WHERE rf.rank = 1;
END;
$$;

SELECT
	*
FROM
	public.most_popular_films_by_countries(ARRAY['Afghanistan', 'Brazil', 'United States']);

-- TASK 4
DROP FUNCTION IF EXISTS public.films_in_stock_by_title (film_title_pattern TEXT);

CREATE OR REPLACE FUNCTION public.films_in_stock_by_title (film_title_pattern TEXT) RETURNS TABLE (
	row_num INT,
	film_title TEXT,
	"language" TEXT,
	customer_name TEXT,
	rental_date DATE
) LANGUAGE plpgsql AS $$
BEGIN
    IF film_title_pattern IS NULL THEN
        RAISE EXCEPTION 'No films matching that title are in stock.';
    END IF;

    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER ()::INT AS row_num,
        film.title AS film_title,
        lang.name::TEXT AS "language",
        cust.first_name || ' ' || cust.last_name AS customer_name,
        rent.rental_date::DATE
    FROM public.customer AS cust
        INNER JOIN public.rental as rent ON cust.customer_id = rent.customer_id
        INNER JOIN public.inventory AS inv ON rent.inventory_id = inv.inventory_id
        INNER JOIN public.film as film ON inv.film_id = film.film_id
        INNER JOIN public.language AS lang ON film.language_id = lang.language_id
    WHERE UPPER(film.title) LIKE UPPER(film_title_pattern);

    -- If no rows were returned above, send fallback message
     IF NOT FOUND THEN
        RAISE EXCEPTION 'No films matching that title are in stock.';
    END IF;
END;
$$;

SELECT
	*
FROM
	films_in_stock_by_title ('%love%');

SELECT
	*
FROM
	films_in_stock_by_title ('%NOFILMS%');

--TASK 5
-- Ensure the function doesn't exist before creating it
DROP FUNCTION IF EXISTS public.new_movie (TEXT, TEXT, INT);

-- Create or Replace the function
CREATE OR REPLACE FUNCTION public.new_movie (
	p_title TEXT,
	p_language TEXT DEFAULT 'Klingon',
	p_release_year INT DEFAULT EXTRACT(
		YEAR
		FROM
			CURRENT_DATE
	)::INT
) RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    v_language_id INT;
BEGIN
    -- Validate that the language exists in the 'language' table
    SELECT language_id INTO v_language_id
    FROM public.language
    WHERE name = p_language;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Language "%" does not exist in the "language" table.', p_language;
    END IF;

    -- Check if the movie with the same title already exists
    IF EXISTS (SELECT 1 FROM public.film WHERE title = p_title) THEN
        RAISE EXCEPTION 'Movie "%" already exists in the film table.', p_title;
    END IF;

    -- Insert the new movie into the 'film' table
    INSERT INTO public.film (title, rental_rate, rental_duration, replacement_cost, release_year, language_id)
    VALUES (
        p_title, 
        4.99,  -- rental_rate
        3,     -- rental_duration (3 days)
        19.99, -- replacement_cost
        p_release_year, 
        v_language_id  
    );
    -- Log a success message
    RAISE NOTICE 'New movie "%" added successfully with language "%" and release year %.', p_title, p_language, p_release_year;
	RETURN p_title;
END;
$$;

--examples
SELECT
	public.new_movie ('Star Trek');

SELECT
	public.new_movie ('Star Trek', 'English', 1977);

SELECT
	public.new_movie ('Bridget Jonnes', 'English');