--Task2: Implement role-based authentication model for dvd_rental database
--Create a new user with the username "rentaluser" and the password "rentalpassword". Give the user the ability to connect to the database but no other permissions.
CREATE ROLE rentaluser WITH LOGIN PASSWORD 'rentalpassword';
GRANT CONNECT ON DATABASE dvdrental2 TO rentaluser; --name in my database is with 2 
GRANT USAGE ON SCHEMA public TO rentaluser;

--Grant "rentaluser" SELECT permission for the "customer" table. Сheck to make sure this permission works correctly—write a SQL query to select all customers.
GRANT SELECT ON TABLE customer TO rentaluser;

SET ROLE rentaluser;
SELECT * FROM public.customer; --should return data
SELECT * FROM public.payment; -- should return statement: permission denied 

--Create a new user group called "rental" and add "rentaluser" to the group. 
SET ROLE postgres; -- get back to my role, because rentaluser does not permissions to create role.

CREATE ROLE rental NOLOGIN; --NOLOGIN makes it a group role 
ALTER ROLE rentaluser INHERIT;

GRANT rental TO rentaluser; -- add rental user to the group, which gives all permissions which rental role has

--Grant the "rental" group INSERT and UPDATE permissions for the "rental" table. Insert a new row and update one existing row in the "rental" table under that role. 
GRANT SELECT ON TABLE public.rental TO rental; -- to update and insert, it needs select statement 
GRANT INSERT, UPDATE ON TABLE public.rental TO rental;

SET ROLE rentaluser;
INSERT INTO public.rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id, last_update
) VALUES (
  (SELECT MAX(rental_id) + 1 FROM rental),
 NOW(), 1, 1, NULL, 1, NOW()
) RETURNING rental_id;

UPDATE public.rental
SET return_date = NOW()
WHERE rental_id = 1
RETURNING *;

--Revoke the "rental" group's INSERT permission for the "rental" table. Try to insert new rows into the "rental" table make sure this action is denied.
SET ROLE postgres;
REVOKE INSERT ON TABLE public.rental FROM rental;
SET ROLE rentaluser;

INSERT INTO public.rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id, last_update
) VALUES (
  (SELECT MAX(rental_id) + 1 FROM rental),
 NOW(), 1, 1, NULL, 1, NOW()
) RETURNING rental_id;

--Create a personalized role for any customer already existing in the dvd_rental database. The name of the role name must be client_{first_name}_{last_name} (omit curly brackets). The customer's payment and rental history must not be empty. 

DO $$
DECLARE
    rec RECORD;
    role_name TEXT;
    role_exists BOOLEAN;
BEGIN
    FOR rec IN SELECT first_name, last_name FROM customer
               WHERE EXISTS (SELECT 1 FROM rental WHERE rental.customer_id = customer.customer_id) 
               AND EXISTS (SELECT 1 FROM payment WHERE payment.customer_id = customer.customer_id)
    LOOP
        -- Create a role name without quotes, using lowercase and underscores
        role_name := 'client_' || lower(regexp_replace(rec.first_name, '\s+', '_', 'g')) || '_' || 
                     lower(regexp_replace(rec.last_name, '\s+', '_', 'g'));
        
        -- Check if role exists
        SELECT EXISTS (
            SELECT 1 FROM pg_roles WHERE rolname = role_name
        ) INTO role_exists;
        
        -- Create role only if it does not exist
        IF NOT role_exists THEN
            EXECUTE format('CREATE ROLE %I WITH NOLOGIN', role_name);
        END IF;
    END LOOP;
END $$;

--Enable row-level security on the rental and payment tables
ALTER TABLE rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment ENABLE ROW LEVEL SECURITY;
--Drop if exists.
DROP POLICY IF EXISTS client_rental_access ON public.rental;
DROP POLICY IF EXISTS client_payment_access ON public.payment;
-- Policy for all client roles on the rental table
CREATE POLICY client_rental_access ON public.rental
    FOR SELECT
    USING (customer_id = (SELECT customer_id FROM public.customer 
                         WHERE lower(regexp_replace(first_name, '\s+', '_', 'g') || '_' || 
                                     regexp_replace(last_name, '\s+', '_', 'g')) = replace(current_user, 'client_', '')));

-- Create RLS policy for payment table
CREATE POLICY client_payment_access ON public.payment
    FOR SELECT
    USING (customer_id = (SELECT customer_id FROM public.customer 
                         WHERE lower(regexp_replace(first_name, '\s+', '_', 'g') || '_' || 
                                     regexp_replace(last_name, '\s+', '_', 'g')) = replace(current_user, 'client_', '')));

-- Step 3: Grant minimal permissions (SELECT only)
GRANT SELECT ON public.rental TO PUBLIC;
GRANT SELECT ON public.payment TO PUBLIC;
GRANT SELECT ON public.customer TO PUBLIC;


DROP FUNCTION IF EXISTS current_user_id();
-- Function to get the current user ID

CREATE OR REPLACE FUNCTION current_user_id() RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT customer_id FROM public.customer 
            WHERE lower(regexp_replace(first_name, '\s+', '_', 'g') || '_' || 
                        regexp_replace(last_name, '\s+', '_', 'g')) = replace(current_user, 'client_', ''));
END;
$$ LANGUAGE plpgsql;


-- check for jennifer davis
ALTER ROLE client_jennifer_davis WITH LOGIN;
SET ROLE client_jennifer_davis;
SELECT * FROM public.rental;
-- Query the payment table
SELECT * FROM public.payment;
-- Reset the session and revoke login
RESET ROLE;
ALTER ROLE client_jennifer_davis WITH NOLOGIN;

