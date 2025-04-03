-- TASK1-- Choose your top-3 favorite movies and add them to the 'film' table (films with the title Film1, Film2, etc - will not be taken into account and grade will be reduced)
-- Fill in rental rates with 4.99, 9.99 and 19.99 and rental durations with 1, 2 and 3 weeks respectively.
-- For formatting SQL I use FORMAT SQL from edit commands, which is built-in in pgAdmin.
-- This approach prevents duplicates and ensures films are only inserted if they font exist. 
INSERT INTO
	FILM (
		TITLE,
		LANGUAGE_ID,
		RENTAL_DURATION,
		RENTAL_RATE,
		REPLACEMENT_COST,
		LAST_UPDATE
	)
SELECT
	*
FROM
	(
		VALUES
			(
				'BRIDGET JONES''S DIARY',
				1,
				7,
				4.99,
				14.99,
				CURRENT_DATE
			),
			('HOME ALONE', 1, 14, 9.99, 19.99, CURRENT_DATE),
			('STEP UP', 1, 21, 19.99, 29.99, CURRENT_DATE)
	) AS NEW_FILMS (
		TITLE,
		LANGUAGE_ID,
		RENTAL_DURATION,
		RENTAL_RATE,
		REPLACEMENT_COST,
		LAST_UPDATE
	)
WHERE
	NOT EXISTS (
		SELECT
			1
		FROM
			FILM F
		WHERE
			F.TITLE = NEW_FILMS.TITLE
	)
RETURNING
	*;

-- Add the actors who play leading roles in your favorite movies to the 'actor' and 'film_actor' tables (6 or more actors in total).  Actors with the name Actor1, Actor2, etc - will not be taken into account and grade will be reduced.
-- step1 --Insert actor into the actor table
-- using simplest way to add actors and using WHERE NOT EXISTS to make sure that data we try to add is not already exists. 
INSERT INTO
	ACTOR (FIRST_NAME, LAST_NAME, LAST_UPDATE)
SELECT
	NEW_ACTORS.FIRST_NAME,
	NEW_ACTORS.LAST_NAME,
	CURRENT_DATE
FROM
	(
		VALUES
			('Robin', 'Williams'),
			('Matt', 'Damon'),
			('Macaulay', 'Culkin'),
			('Emily', 'Watson'),
			('Anne', 'Hathaway'),
			('Channing', 'Tatum')
	) AS NEW_ACTORS (FIRST_NAME, LAST_NAME)
WHERE
	NOT EXISTS (
		SELECT
			1
		FROM
			ACTOR ACT
		WHERE
			ACT.FIRST_NAME = NEW_ACTORS.FIRST_NAME AND 
			ACT.LAST_NAME = NEW_ACTORS.LAST_NAME
	)
RETURNING
	*;

-- Connect film table to actor table.
INSERT INTO
	FILM_ACTOR (ACTOR_ID, FILM_ID, LAST_UPDATE)
SELECT
	ACTOR.ACTOR_ID,
	FILM.FILM_ID,
	CURRENT_DATE
FROM
	(
		VALUES
			('Robin', 'Williams', 'BRIDGET JONES''S DIARY'),
			('Matt', 'Damon', 'STEP UP'),
			('Macaulay', 'Culkin', 'HOME ALONE'),
			('Emily', 'Watson', 'BRIDGET JONES''S DIARY'),
			('Anne', 'Hathaway', 'BRIDGET JONES''S DIARY'),
			('Channing', 'Tatum', 'STEP UP')
	) AS FILM_CAST (FIRST_NAME, LAST_NAME, TITLE)
	INNER JOIN ACTOR ON ACTOR.FIRST_NAME = FILM_CAST.FIRST_NAME AND
	ACTOR.LAST_NAME = FILM_CAST.LAST_NAME
	INNER JOIN FILM ON FILM.TITLE = FILM_CAST.TITLE
WHERE
	NOT EXISTS (
		SELECT
			1
		FROM
			FILM_ACTOR
		WHERE
			FILM_ACTOR.ACTOR_ID = ACTOR.ACTOR_ID AND 
			FILM_ACTOR.FILM_ID = FILM.FILM_ID
	)
RETURNING
	ACTOR_ID,
	FILM_ID;

--Add your favorite movies to any store's inventory.
INSERT INTO
	INVENTORY (FILM_ID, STORE_ID, LAST_UPDATE)
SELECT
	FILM.FILM_ID,
	1,
	CURRENT_DATE -- assuming store_id is 1
FROM
	FILM
WHERE
	FILM.TITLE IN ('BRIDGET JONES''S DIARY', 'HOME ALONE', 'STEP UP')
	AND NOT EXISTS (
		SELECT
			1
		FROM
			INVENTORY I
		WHERE
			I.FILM_ID = FILM.FILM_ID
			AND I.STORE_ID = 1
	)
RETURNING *


--Alter any existing customer in the database with at least 43 rental and 43 payment records. Change their personal data to yours (first name, last name, address, etc.). You can use any existing address from the "address" table. Please do not perform any updates on the "address" table, as this can impact multiple records with the same address.
--using transactions to make sure atomicity
BEGIN;

-- Step 1: Find a customer with at least 43 rental and 43 payment records
WITH
	QUALIFIED_CUSTOMERS AS (
		SELECT
			CUST.CUSTOMER_ID
		FROM
			CUSTOMER CUST
			INNER JOIN RENTAL AS RENT ON CUST.CUSTOMER_ID = RENT.CUSTOMER_ID
			INNER JOIN PAYMENT AS PAY ON CUST.CUSTOMER_ID = PAY.CUSTOMER_ID
		GROUP BY
			CUST.CUSTOMER_ID
		HAVING
			COUNT(DISTINCT RENT.RENTAL_ID) >= 43
			AND COUNT(DISTINCT PAY.PAYMENT_ID) >= 43
		LIMIT
			1 -- Ensures only one customer is selected
	),
	-- Step 2: Select a random existing address
	RANDOM_ADDRESS AS (
		SELECT
			ADDRESS_ID
		FROM
			ADDRESS
		ORDER BY
			RANDOM()
		LIMIT
			1
	)
-- Step 3: Update the selected customer with new details
UPDATE CUSTOMER
SET
	FIRST_NAME = 'Elisabed',
	LAST_NAME = 'Bezhiashvili',
	EMAIL = 'eb@gmail.com',
	ADDRESS_ID = (
		SELECT
			ADDRESS_ID
		FROM
			RANDOM_ADDRESS
	), -- Assign a random address
	LAST_UPDATE = CURRENT_DATE
WHERE
	CUSTOMER_ID = (
		SELECT
			CUSTOMER_ID
		FROM
			QUALIFIED_CUSTOMERS
	)
	AND NOT EXISTS (
		SELECT
			1
		FROM
			CUSTOMER C2
		WHERE
			LOWER(C2.FIRST_NAME) = 'elisabed'
			AND LOWER(C2.LAST_NAME)= 'bezhiashvili'
			AND LOWER(C2.EMAIL) = 'eb@gmail.com'
	)
RETURNING
	CUSTOMER_ID,
	FIRST_NAME,
	LAST_NAME,
	EMAIL,
	ADDRESS_ID,
	LAST_UPDATE;

--Step 4: Verify the updated data
-- SELECT
-- 	CUST.CUSTOMER_ID,
-- 	CUST.FIRST_NAME,
-- 	CUST.LAST_NAME,
-- 	CUST.EMAIL,
-- 	CUST.ADDRESS_ID,
-- 	ADDR.ADDRESS AS NEW_ADDRESS
-- FROM
-- 	CUSTOMER AS CUST
-- 	INNER JOIN ADDRESS AS ADDR ON CUST.ADDRESS_ID = ADDR.ADDRESS_ID
-- WHERE
-- 	CUST.CUSTOMER_ID = (
-- 		SELECT
-- 			CUSTOMER_ID
-- 		FROM
-- 			QUALIFIED_CUSTOMERS
-- 	);

COMMIT;

-- to verify existing data 
SELECT
	CUST.CUSTOMER_ID,
	CUST.FIRST_NAME,
	CUST.LAST_NAME,
	CUST.EMAIL,
	CUST.ADDRESS_ID,
	ADDR.ADDRESS AS ASSIGNED_ADDRESS,
	CUST.LAST_UPDATE
FROM
	CUSTOMER AS CUST
	INNER JOIN ADDRESS AS ADDR ON CUST.ADDRESS_ID = ADDR.ADDRESS_ID
WHERE
	CUST.FIRST_NAME = 'Elisabed'
	AND CUST.LAST_NAME = 'Bezhiashvili'
	AND CUST.EMAIL = 'eb@gmail.com'
	--Remove any records related to you (as a customer) from all tables except 'Customer' and 'Inventory'
	-- Get ID of updated customer.
WITH
	MY_CUSTOMER_ID AS (
		SELECT
			CUSTOMER_ID
		FROM
			CUSTOMER
		WHERE
			FIRST_NAME = 'Elisabed'
			AND LAST_NAME = 'Bezhiashvili'
			AND EMAIL = 'eb@gmail.com'
	)
DELETE FROM PAYMENT
WHERE
	CUSTOMER_ID = (
		SELECT
			CUSTOMER_ID
		FROM
			MY_CUSTOMER_ID
	)
RETURNING
	PAYMENT_ID,
	CUSTOMER_ID,
	AMOUNT,
	PAYMENT_DATE;

DELETE FROM RENTAL
WHERE
	CUSTOMER_ID = (
		SELECT
			CUSTOMER_ID
		FROM
			MY_CUSTOMER_ID
	)
RETURNING
	RENTAL_ID,
	CUSTOMER_ID,
	INVENTORY_ID,
	RETURN_DATE,
	RENTAL_DATE;

-- check if its deleted.
SELECT
	'Payments remaining:',
	COUNT(*)
FROM
	PAYMENT
WHERE
	CUSTOMER_ID = (
		SELECT
			CUSTOMER_ID
		FROM
			MY_CUSTOMER_ID
	);

SELECT
	'Rentals remaining:',
	COUNT(*)
FROM
	RENTAL
WHERE
	CUSTOMER_ID = (
		SELECT
			CUSTOMER_ID
		FROM
			MY_CUSTOMER_ID
	);

-- Start a transaction to ensure all operations are atomic
BEGIN;

-- Get customer_id for Elisabed Bezhiashvili 
WITH
	MY_CUSTOMER_ID AS (
		SELECT
			CUSTOMER_ID
		FROM
			CUSTOMER
		WHERE
			LOWER(FIRST_NAME) = 'elisabed'
			AND LOWER(LAST_NAME) = 'bezhiashvili'
			AND LOWER(EMAIL) = 'eb@gmail.com'
	),
	FILM_INVENTORY AS (
		-- Get inventory_id for each favorite film
		SELECT
			INV.INVENTORY_ID,
			FILM.TITLE
		FROM
			INVENTORY AS INV
			INNER JOIN FILM ON FILM.FILM_ID = INV.FILM_ID
		WHERE
			FILM.TITLE IN ('BRIDGET JONES''S DIARY', 'HOME ALONE', 'STEP UP')
	),
	RENTAL_DATA AS (
		SELECT
			'BRIDGET JONES''S DIARY' AS TITLE,
			'2017-01-01 10:00:00'::TIMESTAMP AS RENTAL_DATE,
			'2017-01-07 10:00:00'::TIMESTAMP AS RETURN_DATE
		UNION ALL
		SELECT
			'HOME ALONE',
			'2017-01-01 10:00:00',
			'2017-01-14 10:00:00'
		UNION ALL
		SELECT
			'STEP UP',
			'2017-01-01: 10:00:00',
			'2017-01-21 10:00:00'
	)
INSERT INTO
	RENTAL (
		RENTAL_DATE,
		INVENTORY_ID,
		CUSTOMER_ID,
		RETURN_DATE,
		STAFF_ID,
		LAST_UPDATE
	)
SELECT
	RENTAL_DATA.RENTAL_DATE,
	FILM_INV.INVENTORY_ID,
	(
		SELECT
			CUSTOMER_ID
		FROM
			MY_CUSTOMER_ID
	),
	RENTAL_DATA.RETURN_DATE,
	(
		SELECT
			STAFF_ID
		FROM
			STAFF
		ORDER BY
			RANDOM()
		LIMIT
			1
	), -- Random staff
	CURRENT_DATE
FROM
	RENTAL_DATA
	INNER JOIN FILM_INVENTORY AS FILM_INV ON FILM_INV.TITLE = RENTAL_DATA.TITLE
	-- Use WHERE NOT EXISTS to avoid duplicate rentals
WHERE
	NOT EXISTS (
		SELECT
			1
		FROM
			RENTAL AS EX_RENTAL
		WHERE
			EX_RENTAL.INVENTORY_ID = FILM_INV.INVENTORY_ID
			AND EX_RENTAL.CUSTOMER_ID = (
				SELECT
					CUSTOMER_ID
				FROM
					MY_CUSTOMER_ID
			)
			AND EX_RENTAL.RENTAL_DATE = RENTAL_DATA.RENTAL_DATE
	)
RETURNING
	RENTAL_ID,
	INVENTORY_ID,
	RENTAL_DATE;

--payment
WITH
	MY_CUSTOMER_ID AS (
		SELECT
			CUSTOMER_ID
		FROM
			CUSTOMER
		WHERE
			FIRST_NAME = 'Elisabed'
			AND LAST_NAME = 'Bezhiashvili'
			AND EMAIL = 'eb@gmail.com'
	),
	FILM_RENTALS AS (
		SELECT
			RENT.RENTAL_ID,
			FILM.TITLE
		FROM
			RENTAL AS RENT
			INNER JOIN INVENTORY INV ON RENT.INVENTORY_ID = INV.INVENTORY_ID
			INNER JOIN FILM ON FILM.FILM_ID = INV.FILM_ID
		WHERE
			UPPER(FILM.TITLE) IN ('BRIDGET JONES''S DIARY', 'HOME ALONE', 'STEP UP')
			AND RENT.CUSTOMER_ID IN (
				SELECT
					CUSTOMER_ID
				FROM
					MY_CUSTOMER_ID
			)
	),
	PAYMENT_DATA AS (
		SELECT
			'BRIDGET JONES''S DIARY' AS TITLE,
			4.99::NUMERIC AS AMOUNT,
			'2017-01-07'::DATE AS PAYMENT_DATE
		UNION ALL
		SELECT
			'HOME ALONE',
			9.99,
			'2017-01-14'
		UNION ALL
		SELECT
			'STEP UP',
			19.99,
			'2017-01-21'
	)
INSERT INTO
	PAYMENT (
		CUSTOMER_ID,
		STAFF_ID,
		RENTAL_ID,
		AMOUNT,
		PAYMENT_DATE
	)
SELECT
	(
		SELECT
			CUSTOMER_ID
		FROM
			MY_CUSTOMER_ID
	),
	(
		SELECT
			STAFF_ID
		FROM
			STAFF
		ORDER BY
			RANDOM()
		LIMIT
			1
	) AS STAFF_ID,
	FILM_RENT.RENTAL_ID,
	PAY_DATA.AMOUNT,
	PAY_DATA.PAYMENT_DATE
FROM
	FILM_RENTALS AS FILM_RENT
	INNER JOIN PAYMENT_DATA AS PAY_DATA ON FILM_RENT.TITLE = PAY_DATA.TITLE
WHERE
	NOT EXISTS (
		SELECT
			1
		FROM
			PAYMENT PAY
		WHERE
			PAY.RENTAL_ID = FILM_RENT.RENTAL_ID
			AND PAY.CUSTOMER_ID = (
				SELECT
					CUSTOMER_ID
				FROM
					MY_CUSTOMER_ID
			)
	)
RETURNING
	*;

COMMIT;

-- check if data is updated
-- SELECT COUNT(*) FROM payment 
-- WHERE customer_id = (
--     SELECT customer_id FROM customer 
--     WHERE lower(first_name) = 'elisabed' AND lower(last_name)='bezhiashvili' and lower(email)='eb@gmail.com'
-- );
-- SELECT * FROM customer 
--  WHERE lower(first_name) = 'elisabed' AND lower(last_name)='bezhiashvili' and lower(email)='eb@gmail.com'
-- -- Check if rentals exist for these films
-- SELECT r.rental_id, f.title 
-- FROM rental r
-- INNER JOIN inventory i ON r.inventory_id = i.inventory_id
-- INNER JOIN film f ON i.film_id = f.film_id
-- INNER JOIN customer c ON r.customer_id = c.customer_id
-- WHERE c.first_name = 'Elisabed' 
-- AND c.last_name = 'Bezhiashvili'
-- AND f.title IN ('BRIDGET JONES''S DIARY', 'HOME ALONE', 'STEP UP');