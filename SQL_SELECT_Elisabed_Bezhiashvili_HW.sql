-- 1.All animation movies released between 2017 and 2019 with rate more than 1, alphabetical
-- select movie titles from the "film" table
-- film - film_catogory - category
-- Business logic: Find all movies in the Animation category, released in the specified time range, with rental rate higher than 1 , and display them in alphabetical order by title.



-- Using INNER JOINs
-- I chose this approach because it's the most straightforward and efficient way to solve this problem.
-- It clearly shows the relationships between tables and is generally the fastest execution method.

SELECT 
	f.title 
FROM 
	film f
	-- joins the 'film_category' table to connect films with their categories
	INNER JOIN film_category fc ON f.film_id=fc.film_id
	-- joins the 'category' table to filter by category name
	INNER JOIN category c ON c.category_id=fc.category_id
	-- filters for movies released between 2017 and 2019
WHERE 
	f.release_year BETWEEN 2017 AND 2019
	-- ensures only 'Animation' category movies are selected
	AND c.name='Animation'
	-- filters only for movies with the specified ratings
	AND f.rental_rate > 1
	-- sorts the result alphabetically by movie title
ORDER BY f.title;


-- Solution 2: Using EXISTS with correlated subquery
--I chose this approach to demonstrate an alternative method that works well when checking if a record exists.This can be beneficial for complex filtering conditions.
SELECT 
	f.title
FROM 
	film f 
WHERE	
	EXISTS (--using exists to check if the film has a corresponding category-animation 
    	SELECT 1
    	FROM film_category fc
	    INNER JOIN category c ON c.category_id = fc.category_id
	    WHERE fc.film_id = f.film_id  -- Match the film's ID with the one in 'film_category'
	    AND c.name = 'Animation'
	) 
	AND f.release_year BETWEEN 2017 AND 2019 -- filter films  released btween 2017 and 2019
	AND f.rental_rate > 1 -- filter films with rental_rate more than 1
ORDER BY 	
	f.title; -- order result alphabetically


-- Solution 3: Using CTE (Common Table Expression)
-- I chose this approach for improved readability and maintainability.
--define CTE to filter films in the animation cateogory
WITH animation_films AS (
    SELECT 	
		f.film_id
    FROM 
		film f
	    INNER JOIN film_category fc ON f.film_id = fc.film_id
	    INNER JOIN category c ON c.category_id = fc.category_id
    WHERE 
        c.name = 'Animation'  -- Filter to only include films in the 'Animation' category
)
--Main query to fetch titles of animation films meeting additional criteria
SELECT 
    f.title
FROM 
    film f
    INNER JOIN animation_films af ON f.film_id = af.film_id
WHERE 
    f.release_year BETWEEN 2017 AND 2019 --filter films by years 
    AND f.rental_rate > 1 -- filter films by rental_rate more than 1 
ORDER BY 
    f.title; -- order the resutl alpabetically


-- 2.The revenue earned by each rental store after March 2017 (columns: address and address2 – as one column, revenue)
-- The goal of this query is to calculate the revenue earned by each rental store after March 2017. cosolidate address and address2 as one column, and calcuate total revenue from the payment.

SELECT 
    CONCAT(a.address, ', ', a.address2) AS store_address,
    SUM(p.amount) AS revenue --calculate total revenue by summing up the payment_amounts
FROM payment p
LEFT JOIN rental r ON p.rental_id = r.rental_id -- Join payment with rental to connect the payment with the rental
LEFT JOIN inventory i ON r.inventory_id = i.inventory_id -- Join rental with inventory to get the related store
LEFT JOIN store s ON i.store_id = s.store_id  -- Join inventory with store to associate the rental with the store
LEFT JOIN address a ON s.address_id = a.address_id -- Join store with address to get the store's address
WHERE p.payment_date > '2017-03-31' --Filter to include only payments made after March 31, 2017
GROUP BY store_address -- Group the results by the store's address
ORDER BY revenue DESC; -- Order the results by revenue in descending order


-- CTE,  I chooe this approach because of better structure, and maintainability and readeble. also improved perfomance
-- also imrpved perfomace, because CTE avoids edundant calculations by computing the revenue once. 
WITH StoreRevenue AS (
    -- This CTE calculates total revenue per store after March 2017
    SELECT 
        i.store_id,
        SUM(p.amount) AS total_revenue
    FROM payment p
    LEFT JOIN rental r ON p.rental_id = r.rental_id
    LEFT JOIN inventory i ON r.inventory_id = i.inventory_id
    WHERE p.payment_date > '2017-03-31' -- Filtering payments after March 2017
    GROUP BY i.store_id
)
SELECT 
    CONCAT(a.address, ', ', COALESCE(a.address2, '')) AS store_address, -- Combine address fields
    sr.total_revenue AS revenue
FROM StoreRevenue sr
LEFT JOIN store s ON sr.store_id = s.store_id
LEFT JOIN address a ON s.address_id = a.address_id
ORDER BY revenue DESC;

-- Subquery
--less code if it used once and more flexible.
SELECT 
    CONCAT(a.address, ', ', COALESCE(a.address2, '')) AS store_address, -- Combine address fields
    (SELECT SUM(p.amount) 
     FROM payment p
     LEFT JOIN rental r ON p.rental_id = r.rental_id
     LEFT JOIN inventory i ON r.inventory_id = i.inventory_id
     WHERE i.store_id = s.store_id 
     AND p.payment_date > '2017-03-31' -- Filter payments after March 2017
    ) AS revenue
FROM store s
LEFT JOIN address a ON s.address_id = a.address_id
ORDER BY revenue DESC;


--Top-5 actors by number of movies (released after 2015) they took part in (columns: first_name, last_name, number_of_movies, sorted by number_of_movies in descending order)
--actor-film_actor-film
-- The goal of this query is to find the top 5 actors by the number of movies they have acted in, released after 2015.
-- The result will include the first name, last name, and the total number of movies for each actor, sorted by the number of movies in descending order.

-- Using direct join and group by
-- This approach is simple, efficient and fast, no need for subquertis and CTEs.
SELECT 
    a.first_name,
    a.last_name,   
    COUNT(fa.film_id) AS number_of_movies  -- Count the number of movies each actor participated in
FROM actor a
JOIN film_actor fa ON a.actor_id = fa.actor_id  -- Join actor table with film_actor to associate actors with movies
JOIN film f ON fa.film_id = f.film_id  -- Join with film table to access the movie release year
WHERE f.release_year > 2015  -- Filter to include only movies released after 2015
GROUP BY a.actor_id, a.first_name, a.last_name  -- Group by actor to calculate total number of movies for each actor
ORDER BY number_of_movies DESC  -- Sort by the number of movies in descending order to get the top actors
LIMIT 5;  -- Limit to top 5 actors based on the number of movies they acted in



-- using CTE- improves readability, Separates the movie count logic from the final selection
-- reusability and perfomance- count function happens only once in the CTE, which avoids redundant calculations.

WITH ActorMovieCount AS (
    -- Count movies per actor for films released after 2015
    SELECT 
        fa.actor_id,
        COUNT(fa.film_id) AS number_of_movies
    FROM film_actor fa
    LEFT JOIN film f ON fa.film_id = f.film_id
    WHERE f.release_year > 2015 -- Filter only movies released after 2015
    GROUP BY fa.actor_id
)
SELECT 
    a.first_name, 
    a.last_name, 
    amc.number_of_movies
FROM ActorMovieCount amc
LEFT JOIN actor a ON amc.actor_id = a.actor_id
ORDER BY amc.number_of_movies DESC
LIMIT 5; -- Get only the top 5 actors
SELECT 
    a.first_name, 
    a.last_name, 
    (SELECT COUNT(fa.film_id)
     FROM film_actor fa
     LEFT JOIN film f ON fa.film_id = f.film_id
     WHERE fa.actor_id = a.actor_id
     AND f.release_year > 2015
    ) AS number_of_movies
FROM actor a
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
    f.release_year,
    COALESCE(SUM(CASE WHEN c.name = 'Drama' THEN 1 ELSE 0 END), 0) AS number_of_drama_movies,
    COALESCE(SUM(CASE WHEN c.name = 'Travel' THEN 1 ELSE 0 END), 0) AS number_of_travel_movies,
    COALESCE(SUM(CASE WHEN c.name = 'Documentary' THEN 1 ELSE 0 END), 0) AS number_of_documentary_movies
FROM film f
LEFT JOIN film_category fc ON f.film_id = fc.film_id
LEFT JOIN category c ON fc.category_id = c.category_id
WHERE c.name IN ('Drama', 'Travel', 'Documentary') -- Filter only required categories
GROUP BY f.release_year
ORDER BY f.release_year DESC;

-- using subqery and count function
-- using filter where contiion sytanx is clean and ingnores null values automatically.
SELECT 
    sub.release_year,-- The year in which the movie was released
	---- Count movies for each category
    COUNT(*) FILTER (WHERE sub.category = 'Drama') AS number_of_drama_movies,
    COUNT(*) FILTER (WHERE sub.category = 'Travel') AS number_of_travel_movies,
    COUNT(*) FILTER (WHERE sub.category = 'Documentary') AS number_of_documentary_movies
FROM (
    -- Subquery to retrieve the release year and category of films
    SELECT 
        f.release_year,
        c.name AS category
    FROM film f
	-- Join to associate each film with its category
    LEFT JOIN film_category fc ON f.film_id = fc.film_id
    LEFT JOIN category c ON fc.category_id = c.category_id
    WHERE c.name IN ('Drama', 'Travel', 'Documentary') -- Filter only relevant categories
) AS sub
GROUP BY sub.release_year -- Group the results by release year to aggregate category counts per year
ORDER BY sub.release_year DESC;-- Order the results in descending order of release year (latest movies first)


-- using CTE
-- This approach improves readability, sepetares filtering logic from aggregation and it has reusable query.

WITH categorized_movies AS (
    SELECT 
        f.release_year,
        c.name AS category
    FROM film f
    LEFT JOIN film_category fc ON f.film_id = fc.film_id
    LEFT JOIN category c ON fc.category_id = c.category_id
    WHERE c.name IN ('Drama', 'Travel', 'Documentary') -- Filter required categories
)
SELECT 
    cm.release_year,
    COALESCE(SUM(CASE WHEN cm.category = 'Drama' THEN 1 ELSE 0 END), 0) AS number_of_drama_movies,
    COALESCE(SUM(CASE WHEN cm.category = 'Travel' THEN 1 ELSE 0 END), 0) AS number_of_travel_movies,
    COALESCE(SUM(CASE WHEN cm.category = 'Documentary' THEN 1 ELSE 0 END), 0) AS number_of_documentary_movies
FROM categorized_movies cm
GROUP BY cm.release_year
ORDER BY cm.release_year DESC;

--Part 2: Solve the following problems using SQL
--1.Which three employees generated the most revenue in 2017? They should be awarded a bonus for their outstanding performance. 
-- payment-staff-store
--Business logic:The query aims to identify the top three employees who generated the most revenue in 2017 and determine the store where they last worked. The revenue is calculated by summing up the amount from the payment table where the staff_id matches and the payment date is in 2017. The last store is determined by identifying the most recent payment record for each employee. 

--using subeqery. I chose to use subqueries here because they offer a straightforward, modular approach to calculating total revenue and identifying the last store for each employee. They are easy to implement and provide a clear structure for the task at hand. 
SELECT 
    s.staff_id,
    s.first_name,
    s.last_name,
    -- Get total revenue for each staff member in 2017
    (SELECT SUM(p.amount)
     FROM payment p
     WHERE p.staff_id = s.staff_id
       AND EXTRACT(YEAR FROM p.payment_date) = 2017) AS total_revenue,
    -- Get last store where staff worked in 2017
    (SELECT st.store_id
     FROM payment p
     JOIN staff st ON p.staff_id = st.staff_id
     WHERE p.staff_id = s.staff_id
       AND EXTRACT(YEAR FROM p.payment_date) = 2017
     ORDER BY p.payment_date DESC, p.payment_id DESC
     LIMIT 1) AS last_store
FROM staff s
WHERE s.staff_id IN (
    -- Select top 3 employees based on revenue
    SELECT p.staff_id
    FROM payment p
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
    GROUP BY p.staff_id
    ORDER BY SUM(p.amount) DESC
    LIMIT 3
)
ORDER BY total_revenue DESC;



-- using CTE is a modular approch, seperates calculation of revenue and last store lookup, improves readability so each step is logically divided. and better perfomance for large datasets.
-- CTE to calculate total revenue per staff member in 2017 and their last payment date
WITH StaffRevenue AS (
    SELECT 
        s.staff_id,  
        s.first_name,  
        s.last_name,  
        SUM(p.amount) AS total_revenue,  
        MAX(p.payment_date) AS last_payment_date
    FROM staff s
    JOIN payment p ON s.staff_id = p.staff_id  
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
    GROUP BY s.staff_id, s.first_name, s.last_name
)
-- Retrieve the last store the employee worked at by joining with staff table
SELECT 
    sr.staff_id,
    sr.first_name,
    sr.last_name,
    sr.total_revenue,
    s.store_id AS last_store -- Get store_id from staff table
FROM StaffRevenue sr
JOIN staff s ON sr.staff_id = s.staff_id
ORDER BY sr.total_revenue DESC
LIMIT 3;


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
        f.film_id,
        f.title,
        COUNT(r.rental_id) AS rental_count,  -- Number of times this film was rented
        f.rating -- Get the film rating (MPAA rating)
    FROM film f
    -- Join inventory to connect rentals to films
    JOIN inventory i ON f.film_id = i.film_id
    -- Joining the rental table to count how many times a film was rented
    JOIN rental r ON i.inventory_id = r.inventory_id
    GROUP BY f.film_id, f.title, f.rating
)
-- Get the top 5 movies by rental count and the expected audience age
SELECT 
    mr.title,
    mr.rental_count,
    mr.rating,
    CASE 
		--cases for each type of MPAA rating
        WHEN mr.rating = 'G' THEN 'Everyone'
        WHEN mr.rating = 'PG' THEN '5+'
        WHEN mr.rating = 'PG-13' THEN '13+'
        WHEN mr.rating = 'R' THEN '17+'
        WHEN mr.rating = 'NC-17' THEN '18+'
        ELSE 'Unknown'
    END AS expected_audience_age
FROM MovieRentals mr
ORDER BY mr.rental_count DESC -- sorting movies by rental numbers
LIMIT 5; --return only the top 5 most rented




-- Direct approach -It is more simple and executes in one step.
SELECT 
    f.title,
    f.rating,
    COUNT(r.rental_id) AS rental_count,
    CASE 
        WHEN f.rating = 'G' THEN 'All ages'
        WHEN f.rating = 'PG' THEN '7+'
        WHEN f.rating = 'PG-13' THEN '13+'
        WHEN f.rating = 'R' THEN '17+'
        WHEN f.rating = 'NC-17' THEN '18+'
        ELSE 'Unknown'
    END AS expected_audience_age
FROM 
    film f
JOIN 
    inventory i ON f.film_id = i.film_id
JOIN 
    rental r ON i.inventory_id = r.inventory_id
GROUP BY 
    f.film_id, f.title, f.rating
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
select * from film

SELECT 
    a.first_name,
    a.last_name,
    MAX(f.release_year) AS last_movie_year,   -- Get the most recent movie year for each actor
    EXTRACT(YEAR FROM CURRENT_DATE) - MAX(f.release_year) AS years_since_last_movie 
FROM actor a
JOIN film_actor fa ON a.actor_id = fa.actor_id  -- Link actors to movies
JOIN film f ON fa.film_id = f.film_id
GROUP BY a.actor_id, a.first_name, a.last_name -- Group by actor to get their last movie
ORDER BY years_since_last_movie DESC  -- Sort actors by longest inactivity period
LIMIT 10; -- Shows the top 10 actors who haven't acted in the longest time


-- gaps between sequential films per each actor;
--It finds the largest gap between two different movies for each actor.
-- simple aggregation with group by

WITH ActorMovies AS (
    -- Get all movie release years per actor
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        f.release_year
    FROM actor a
    JOIN film_actor fa ON a.actor_id = fa.actor_id  -- Link actors to movies
    JOIN film f ON fa.film_id = f.film_id
),
ActorGaps AS (
    -- Self-join to find the next movie after the current one
    SELECT 
        am1.actor_id,
        am1.first_name,
        am1.last_name,
        am1.release_year AS movie_year,
        MIN(am2.release_year) AS next_movie_year  -- Get the closest movie after the current one
    FROM ActorMovies am1
    LEFT JOIN ActorMovies am2 
        ON am1.actor_id = am2.actor_id 
        AND am2.release_year > am1.release_year  -- Ensure it's the next movie
    GROUP BY am1.actor_id, am1.first_name, am1.last_name, am1.release_year
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


