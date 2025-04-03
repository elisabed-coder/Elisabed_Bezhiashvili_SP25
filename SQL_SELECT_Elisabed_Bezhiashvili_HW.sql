-- 1.All animation movies released between 2017 and 2019 with rate more than 1, alphabetical
-- select movie titles from the "film" table
-- film - film_catogory - category
-- Business logic: Find all movies in the Animation category, released in the specified time range, with rental rate higher than 1 , and display them in alphabetical order by title.

SET search_path TO public; 


-- Using INNER JOINs
-- I chose this approach because it's the most straightforward and efficient way to solve this problem.
-- It clearly shows the relationships between tables and is generally the fastest execution method.

SELECT 
	film.title 
FROM 
	film
	-- joins the 'film_category' table to connect films with their categories
	INNER JOIN film_category AS film_cat ON film.film_id=film_cat.film_id
	-- joins the 'category' table to filter by category name
	INNER JOIN category AS cat ON film_cat.category_id=cat.category_id
	-- filters for movies released between 2017 and 2019
WHERE 
	film.release_year BETWEEN 2017 AND 2019 AND
	-- ensures only 'Animation' category movies are selected
	UPPER(cat.name)='ANIMATION' AND
	-- filters only for movies with the specified ratings
	film.rental_rate > 1
	-- sorts the result alphabetically by movie title
ORDER BY film.title;


-- Solution 2: Using EXISTS with correlated subquery
--I chose this approach to demonstrate an alternative method that works well when checking if a record exists.This can be beneficial for complex filtering conditions.
SELECT 
	film.title
FROM 
	film
WHERE	
	EXISTS (--using exists to check if the film has a corresponding category-animation 
    	SELECT 1
    	FROM film_category AS film_cat
	    INNER JOIN category AS cat ON cat.category_id = film_cat.category_id
	    WHERE film_cat.film_id = film.film_id AND -- Match the film's ID with the one in 'film_category'
	    UPPER(cat.name) = 'ANIMATION'
	) AND
	film.release_year BETWEEN 2017 AND 2019 AND-- filter films  released btween 2017 and 2019
	film.rental_rate > 1 -- filter films with rental_rate more than 1
ORDER BY 	
	film.title; -- order result alphabetically


-- Solution 3: Using CTE (Common Table Expression)
-- I chose this approach for improved readability and maintainability.
--define CTE to filter films in the animation cateogory
WITH animation_films AS (
    SELECT 	
		film.film_id
    FROM 
		film
	    INNER JOIN film_category AS film_cat ON film.film_id = film_cat.film_id
	    INNER JOIN category AS cat ON cat.category_id = film_cat.category_id
    WHERE 
        UPPER(cat.name) = 'ANIMATION'  -- Filter to only include films in the 'Animation' category
)
--Main query to fetch titles of animation films meeting additional criteria
SELECT 
    film.title
FROM 
    film
    INNER JOIN animation_films AS animations ON film.film_id = animations.film_id
WHERE 
    film.release_year BETWEEN 2017 AND 2019 AND --filter films by years 
    film.rental_rate > 1 -- filter films by rental_rate more than 1 
ORDER BY 
    film.title; -- order the resutl alpabetically


-- 2.The revenue earned by each rental store after March 2017 (columns: address and address2 – as one column, revenue)
-- The goal of this query is to calculate the revenue earned by each rental store after March 2017. cosolidate address and address2 as one column, and calcuate total revenue from the payment.
-- left join are used to ensure that all payment records are inculeded, even some rental or inventory data are missing.
-- If our data integrity guarantees that every payment has a matching rental, inventory, and store record, then we could replace these with INNER JOINs.

SELECT 
    CONCAT(addr.address, ', ', addr.address2) AS store_address,
    SUM(pay.amount) AS total_amount -- Calculate total revenue by summing up the payment amounts
FROM payment AS pay
-- Join payment with rental to connect the payment with the rental
LEFT JOIN rental AS rent ON pay.rental_id = rent.rental_id
-- Join rental with inventory to get the related store
LEFT JOIN inventory AS inv ON rent.inventory_id = inv.inventory_id
-- Join inventory with store to associate the rental with the store
LEFT JOIN store AS st ON inv.store_id = st.store_id  
-- Join store with address to get the store's address
LEFT JOIN address AS addr ON st.address_id = addr.address_id
WHERE pay.payment_date >= '2017-04-01' -- Filter to include only payments made after March 31, 2017
GROUP BY addr.address_id -- Group by the store's address components
ORDER BY total_amount DESC; -- Order the results by revenue in descending order

-- CTE,  I chooe this approach because of better structure, and maintainability and readeble. also improved perfomance
-- also imrpved perfomace, because CTE avoids edundant calculations by computing the revenue once. 
WITH StoreRevenue AS (
    -- This CTE calculates total revenue per store after March 2017
    SELECT 
        inv.store_id,
        SUM(pay.amount) AS total_amount
    FROM payment pay
    LEFT JOIN rental rent ON pay.rental_id = rent.rental_id
    LEFT JOIN inventory inv ON rent.inventory_id = inv.inventory_id
	WHERE pay.payment_date >= '2017-04-01' -- Filter to include only payments made after March 31, 2017
    GROUP BY inv.store_id
)
SELECT 
    CONCAT(addr.address, ', ', COALESCE(addr.address2, '')) AS store_address, -- Combine address fields
    store_rev.total_amount AS revenue  
FROM StoreRevenue AS store_rev
LEFT JOIN store st ON store_rev.store_id = st.store_id
LEFT JOIN address addr ON st.address_id = addr.address_id
ORDER BY revenue DESC;

-- Subquery
--less code if it used once and more flexible.
SELECT 
    CONCAT(addr.address, ', ', COALESCE(addr.address2, '')) AS store_address, -- Combine address fields
    (SELECT SUM(pay.amount) 
     FROM payment pay
     LEFT JOIN rental rent ON pay.rental_id = rent.rental_id
     LEFT JOIN inventory inv ON rent.inventory_id = inv.inventory_id
     WHERE inv.store_id = st.store_id 
     AND pay.payment_date >= '2017-04-01' -- Filter payments after March 2017
    ) AS revenue
FROM store st
LEFT JOIN address addr ON st.address_id = addr.address_id
ORDER BY revenue DESC;


--Top-5 actors by number of movies (released after 2015) they took part in (columns: first_name, last_name, number_of_movies, sorted by number_of_movies in descending order)
--actor-film_actor-film
-- The goal of this query is to find the top 5 actors by the number of movies they have acted in, released after 2015.
-- The result will include the first name, last name, and the total number of movies for each actor, sorted by the number of movies in descending order.

-- Using direct join and group by
-- This approach is simple, efficient and fast, no need for subquertis and CTEs.
SELECT 
    actor.first_name,
    actor.last_name,   
    COUNT(film_actor.film_id) AS number_of_films  -- Count the number of movies each actor participated in
FROM actor
INNER JOIN film_actor ON actor.actor_id = film_actor.actor_id  -- Join actor table with film_actor to associate actors with movies
INNER JOIN film ON film_actor.film_id = film.film_id  -- Join with film table to access the movie release year
WHERE film.release_year > 2015  -- Filter to include only movies released after 2015
GROUP BY actor.actor_id -- Group by actor to calculate total number of movies for each actor
ORDER BY number_of_films DESC  -- Sort by the number of movies in descending order to get the top actors
LIMIT 5;  -- Limit to top 5 actors based on the number of movies they acted in



-- using CTE- improves readability, Separates the movie count logic from the final selection
-- reusability and perfomance- count function happens only once in the CTE, which avoids redundant calculations.

WITH ActorMovieCount AS (
    -- Count movies per actor for films released after 2015
    SELECT 
        fa.actor_id,
        COUNT(fa.film_id) AS number_of_films
    FROM film_actor fa
    LEFT JOIN film ON fa.film_id = film.film_id
    WHERE film.release_year > 2015 -- Filter only movies released after 2015
    GROUP BY fa.actor_id
)
SELECT 
    act.first_name, 
    act.last_name, 
    counted_movies.number_of_films
FROM ActorMovieCount as counted_movies
LEFT JOIN actor act ON counted_movies.actor_id = act.actor_id
ORDER BY counted_movies.number_of_films DESC
LIMIT 5; -- Get only the top 5 actors
SELECT 
    act.first_name, 
    act.last_name, 
    (SELECT COUNT(fa.film_id)
     FROM film_actor fa
     LEFT JOIN film ON fa.film_id = film.film_id
     WHERE fa.actor_id = act.actor_id
     AND film.release_year > 2015
    ) AS number_of_movies
FROM actor act
ORDER BY number_of_movies DESC
LIMIT 5;




--Number of Drama, Travel, Documentary per year (columns: release_year, number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies), sorted by release year in descending order. Dealing with NULL values is encouraged)
--film- film_category-category
--Business Logic :The task at hand requires generating a report that shows the number of movies in three specific categories: Drama, Travel, and Documentary, released per year. The goal is to produce


--solution using conditional aggregation
--this approach seperately counts movies for each category
--ensures that if category has null, it replaces it with 0
--using left join ensures that all movies are included
SELECT 
    film.release_year,
    COALESCE(SUM(CASE WHEN UPPER(cat.name) = 'DRAMA' THEN 1 ELSE 0 END), 0) AS number_of_drama_movies,
    COALESCE(SUM(CASE WHEN UPPER(cat.name) = 'TRAVEL' THEN 1 ELSE 0 END), 0) AS number_of_travel_movies,
    COALESCE(SUM(CASE WHEN UPPER(cat.name) = 'DOCUMENTARY' THEN 1 ELSE 0 END), 0) AS number_of_documentary_movies
FROM film
LEFT JOIN film_category AS film_cat ON film.film_id = film_cat.film_id
LEFT JOIN category AS cat ON film_cat.category_id = cat.category_id
WHERE UPPER(cat.name) IN ('DRAMA', 'TRAVEL', 'DOCUMENTARY') -- Filter only required categories
GROUP BY film.release_year -- sorts the results by release year in descending order.
ORDER BY film.release_year DESC;

-- using subqery and count function
-- using filter where contiion sytanx is clean and ingnores null values automatically.
SELECT 
    sub.release_year,-- The year in which the movie was released
	---- Count movies for each category
    COUNT(*) FILTER (WHERE LOWER(sub.category) = 'drama') AS number_of_drama_movies,
    COUNT(*) FILTER (WHERE LOWER(sub.category) = 'travel') AS number_of_travel_movies,
    COUNT(*) FILTER (WHERE LOWER(sub.category) = 'documentary') AS number_of_documentary_movies
FROM (
    -- Subquery to retrieve the release year and category of films
    SELECT 
        film.release_year,
        cat.name AS category
    FROM film
	-- Join to associate each film with its category
    LEFT JOIN film_category filmcat ON film.film_id = filmcat.film_id
    LEFT JOIN category cat ON filmcat.category_id = cat.category_id
    WHERE LOWER(cat.name) IN ('drama', 'travel', 'documentary') -- Filter only relevant categories
) AS sub
GROUP BY sub.release_year -- Group the results by release year to aggregate category counts per year
ORDER BY sub.release_year DESC;-- Order the results in descending order of release year (latest movies first)


-- using CTE
-- This approach improves readability, sepetares filtering logic from aggregation and it has reusable query.

WITH categorized_movies AS (
    SELECT 
        film.release_year,
        cat.name AS category
    FROM film
    LEFT JOIN film_category film_cat ON film.film_id = film_cat.film_id
    LEFT JOIN category cat ON film_cat.category_id = cat.category_id
    WHERE LOWER(cat.name) IN ('drama', 'travel', 'documentary') -- Filter required categories
)
SELECT 
    movie_data.release_year,
    COALESCE(SUM(CASE WHEN LOWER(movie_data.category) = 'drama' THEN 1 ELSE 0 END), 0) AS number_of_drama_movies,
    COALESCE(SUM(CASE WHEN LOWER(movie_data.category) = 'travel' THEN 1 ELSE 0 END), 0) AS number_of_travel_movies,
    COALESCE(SUM(CASE WHEN LOWER(movie_data.category) = 'documentary' THEN 1 ELSE 0 END), 0) AS number_of_documentary_movies
FROM categorized_movies movie_data
GROUP BY movie_data.release_year
ORDER BY movie_data.release_year DESC;

--Part 2: Solve the following problems using SQL
--1.Which three employees generated the most revenue in 2017? They should be awarded a bonus for their outstanding performance. 
-- payment-staff-store
--Business logic:The query aims to identify the top three employees who generated the most revenue in 2017 and determine the store where they last worked. The revenue is calculated by summing up the amount from the payment table where the staff_id matches and the payment date is in 2017. The last store is determined by identifying the most recent payment record for each employee. 

-- Step 1: Create a temporary table (CTE) that associates rentals with store locations
WITH rental_store_mapping AS (
    SELECT rental.rental_id, 
           inventory.store_id
    FROM public.rental
    INNER JOIN public.inventory ON rental.inventory_id = inventory.inventory_id
),
-- Step 2: Identify the latest payment for each staff member in each store
-- We filter payments from the year 2017 to reduce data size and improve performance.
latest_payment_per_store AS (
    SELECT payment.staff_id,
           rental_store_mapping.store_id,
           MAX(payment.payment_id) AS latest_payment_id, -- Get latest payment transaction ID
           MAX(payment.payment_date) AS latest_payment_date -- Get latest payment date
    FROM public.payment
    INNER JOIN rental_store_mapping ON payment.rental_id = rental_store_mapping.rental_id
    WHERE EXTRACT(YEAR FROM payment.payment_date) = 2017 -- Filter only 2017 data
    GROUP BY payment.staff_id, rental_store_mapping.store_id
),
-- Step 3: Identify the latest payment for each staff member across all stores
-- This is done using a self-join to compare payment IDs within each staff group.
latest_payment_per_staff AS (
    SELECT *
    FROM latest_payment_per_store latest
    WHERE latest.latest_payment_id = (
        SELECT MAX(inner_latest.latest_payment_id) 
        FROM latest_payment_per_store inner_latest
        WHERE latest.staff_id = inner_latest.staff_id
        GROUP BY inner_latest.staff_id 
    )
)

-- Step 4: Calculate the total revenue per staff member for 2017
SELECT staff.first_name,
       staff.last_name,
       latest_payment_per_staff.store_id,
       SUM(payment.amount) AS payment
FROM public.payment
INNER JOIN public.staff ON payment.staff_id = staff.staff_id
INNER JOIN latest_payment_per_staff ON payment.staff_id = latest_payment_per_staff.staff_id
GROUP BY staff.staff_id, latest_payment_per_staff.store_id;
-- Step 5: Retrieve the top 3 staff members based on revenue
WITH StaffRevenue AS (
    SELECT 
        staff.staff_id,  
        staff.first_name,  
        staff.last_name,  
        SUM(payment.amount) AS total_payment,  -- Calculate total revenue per staff
        MAX(payment.payment_date) AS last_payment_date -- Get last payment date
    FROM public.staff
    INNER JOIN public.payment ON staff.staff_id = payment.staff_id  
    WHERE EXTRACT(YEAR FROM payment.payment_date) = 2017 -- Filter payments for 2017
    GROUP BY staff.staff_id, staff.first_name, staff.last_name
)
-- Step 6: Identify the last store each employee worked in
SELECT 
    StaffRevenue.staff_id,
    StaffRevenue.first_name,
    StaffRevenue.last_name,
    StaffRevenue.total_payment,
    staff.store_id AS last_store -- Store ID retrieved from staff table
FROM StaffRevenue
INNER JOIN public.staff ON StaffRevenue.staff_id = staff.staff_id
ORDER BY StaffRevenue.total_payment DESC
LIMIT 3; -- Return only the top 3 employees with the highest revenue


-- 2. Which 5 movies were rented more than others (number of rentals), and what's the expected age of the audience for these movies? To determine expected age please use 'Motion Picture Association film rating system
--The task involves identifying the top 5 most rented movies and determining the expected age of the audience based on the Motion Picture Association (MPAA) film rating system. To do this, we need to track the number of rentals associated with each movie and calculate the rental count by joining the film, inventory, and rental tables. The MPAA rating system categorizes audiences by age range, such as G, PG, PG-13, R, and NC-17. We will map the MPAA film rating to its expected audience age using a CASE statement. This information is useful for stock management, marketing, and making better purchasing decisions for future inventory. Understanding the expected age group of the most rented movies can help tailor marketing efforts and ensure content is marketed to the correct demographic. Studios and rental services can also predict demand and manage inventory accordingly. The solution strategy is either a Common Table Expression (CTE) or a direct query.
/* Table Relationships:
   - film: Contains movie information including title and rating
   - inventory: Links films to physical copies available for rent
      → inventory.film_id connects to film.film_id
   - rental: Tracks when movies were rented out
      → rental.inventory_id connects to inventory.inventory_id
*/

--Using  CTE makes the query more modular and easier to read. IT allows to calculate rental counts once and if needed use it in mutiple queries
-- using case statements allows yo mapping it to audience age groups and interpreting the results.

WITH MovieRentals AS (
    -- Count the number of rentals per movie by joining film -> inventory -> rental
    SELECT 
        film.film_id,
        film.title,
        COUNT(rent.rental_id) AS rental_count,  -- Number of times this film was rented
        film.rating -- Get the film rating (MPAA rating)
    FROM film
    -- Join inventory to connect rentals to films
    INNER JOIN inventory inv ON film.film_id = inv.film_id
    -- Joining the rental table to count how many times a film was rented
    INNER JOIN rental rent ON inv.inventory_id = rent.inventory_id
    GROUP BY film.film_id
)
-- Get the top 5 movies by rental count and the expected audience age
SELECT 
    rental_data.title,
    rental_data.rental_count,
    rental_data.rating,
    CASE 
		--cases for each type of MPAA rating
        WHEN rental_data.rating = 'G' THEN 'Everyone'
        WHEN rental_data.rating = 'PG' THEN 'Parental Guidance'
        WHEN rental_data.rating = 'PG-13' THEN '13+'
        WHEN rental_data.rating = 'R' THEN '17+'
        WHEN rental_data.rating = 'NC-17' THEN '18+'
        ELSE 'Unknown'
    END AS expected_audience_age
FROM MovieRentals as rental_data
ORDER BY rental_data.rental_count DESC -- sorting movies by rental numbers
LIMIT 5; --return only the top 5 most rented




-- Direct approach -It is more simple and executes in one step.
SELECT 
    film.title,
    film.rating,
    COUNT(rent.rental_id) AS rental_count,
    CASE 
        WHEN film.rating = 'G' THEN 'All ages'
        WHEN film.rating = 'PG' THEN 'Parental Guidance'
        WHEN film.rating = 'PG-13' THEN '13+'
        WHEN film.rating = 'R' THEN '17+'
        WHEN film.rating = 'NC-17' THEN '18+'
        ELSE 'Unknown'
    END AS expected_audience_age
FROM 
    film
INNER JOIN 
    inventory inv ON film.film_id = inv.film_id
INNER JOIN 
    rental rent ON inv.inventory_id = rent.inventory_id
GROUP BY 
    film.film_id
ORDER BY 
    rental_count DESC
LIMIT 5;



-- Part 3. Which actors/actresses didn't act for a longer period of time than the others? 
-- actor table contains actor_id, fist_name, last_name, film_actor contains film_id and actor_id and it is a juntion table which connects actor table to film table.  Film table contains infomariton about film  title, description and other columns about films.
-- film_actor table sets relationship many-tp-many betwween actor and film - An actor can appear in many films, and a film can have multiple actors. Between film and film_actor is one-to-many.
--Business logic: The task involves identifying actors who have been inactive for the longest time by calculating the gap between their most recent film's release year and the current year. The gap is calculated as the difference between the current year and the actor's most recent film. The goal is to identify actors with the longest gaps between their latest movie release and the current year. This helps talent management, casting decisions, and career insight. The process involves identifying the most recent film each actor has worked on, calculating the time gap between the current year and the release year of that film, and ranking actors by the length of their inactivity.
-- Gap between latest release year an current year
-- This query helps identify actors who have been inactive for the longest time.
-- It calculates gap between their most  recent film and current year
-- logic is straighforward 
SELECT 
    act.first_name,
    act.last_name,
    MAX(film.release_year) AS last_movie_year,  
    EXTRACT(YEAR FROM CURRENT_DATE) - COALESCE(MAX(film.release_year), EXTRACT(YEAR FROM CURRENT_DATE)) AS years_since_last_movie 
FROM actor act
LEFT JOIN film_actor ON act.actor_id = film_actor.actor_id  
LEFT JOIN film ON film_actor.film_id = film.film_id
GROUP BY act.actor_id
ORDER BY years_since_last_movie DESC 
LIMIT 10;


-- gaps between sequential films per each actor;
--It finds the largest gap between two different movies for each actor.
-- simple aggregation with group by

WITH ActorMovies AS (
    -- Get all movie release years per actor
    SELECT 
        act.actor_id,
        act.first_name,
        act.last_name,
        film.release_year
    FROM actor act
    INNER JOIN film_actor as film_act ON act.actor_id = film_act.actor_id  -- Link actors to movies
    INNER JOIN film ON film_act.film_id = film.film_id
),
ActorGaps AS (
    -- Self-join to find the next movie after the current one
    SELECT 
        current_actor_movies.actor_id,
        current_actor_movies.first_name,
        current_actor_movies.last_name,
        current_actor_movies.release_year AS movie_year,
        MIN(next_actor_movies.release_year) AS next_movie_year  -- Get the closest movie after the current one
    FROM ActorMovies AS current_actor_movies
    LEFT JOIN ActorMovies AS next_actor_movies 
        ON current_actor_movies.actor_id = next_actor_movies.actor_id 
        AND next_actor_movies.release_year > current_actor_movies.release_year  -- Ensure it's the next movie
    GROUP BY current_actor_movies.actor_id, current_actor_movies.first_name, current_actor_movies.last_name, current_actor_movies.release_year
)
-- Find the longest gap for each actor
SELECT 
    actor_id,
    first_name,
    last_name,
    MAX(next_movie_year - movie_year) AS longest_gap  -- Get the largest gap per actor
FROM ActorGaps
WHERE next_movie_year IS NOT NULL  -- Ignore cases where no next movie exists
GROUP BY actor_id, first_name, last_name
ORDER BY longest_gap DESC  -- Order by longest gap first
LIMIT 10;  -- Get the top 10 actors with the longest gap between two movies


