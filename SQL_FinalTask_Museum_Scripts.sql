-- Database: museum_db
DROP DATABASE IF EXISTS museum_db;

-- DROP DATABASE IF EXISTS museum_db;

CREATE DATABASE museum_db
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en-US'
    LC_CTYPE = 'en-US'
    LOCALE_PROVIDER = 'libc'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

-- Create Schema use if not exists for rerunnability
CREATE SCHEMA IF NOT EXISTS museum;

-- Create tables
-- LOCATION table
CREATE TABLE IF NOT EXISTS museum.location (
    location_id SERIAL PRIMARY KEY,
    location_name VARCHAR(100) NOT NULL,
    description TEXT
);

-- CATEGORY table
CREATE TABLE IF NOT EXISTS museum.category (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    description TEXT
);

-- EMPLOYEE table
CREATE TABLE IF NOT EXISTS museum.employee (
    employee_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    position VARCHAR(50),-- update with alter
);

-- VISITOR table
CREATE TABLE IF NOT EXISTS museum.visitor (
    visitor_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL
);

-- ITEM table
CREATE TABLE IF NOT EXISTS museum.item (
    item_id SERIAL PRIMARY KEY,
    item_name VARCHAR(100),
    category_id INTEGER NOT NULL REFERENCES museum.category(category_id),
    description TEXT
);


-- EXHIBITION table
CREATE TABLE IF NOT EXISTS museum.exhibition (
    exhibition_id SERIAL PRIMARY KEY,
    exhibition_name VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL, -- ADD WITH ALTER -date to be inserted, which must be greater than January 1, 2024
    end_date DATE NOT NULL,
	is_online BOOLEAN NOT NULL,
	url VARCHAR(255),
    curator_id INT REFERENCES museum.employee(employee_id),
	price DECIMAL(8,2) , -- add with alter DEFAULT 0
	is_free BOOLEAN,
	CONSTRAINT check_exhibition_dates CHECK (end_date > start_date)
);

-- EXHIBITION_ITEM join table (many-to-many between exhibitions and items)
CREATE TABLE IF NOT EXISTS museum.exhibition_item (
    exhibition_item_id SERIAL PRIMARY KEY,
    exhibition_id INTEGER NOT NULL REFERENCES museum.exhibition(exhibition_id),
    item_id INTEGER NOT NULL REFERENCES museum.item(item_id)
);

-- ITEM_LOCATION join table (tracks items at locations)
CREATE TABLE IF NOT EXISTS museum.item_location (
    item_location_id SERIAL PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES museum.item(item_id),
    location_id INTEGER NOT NULL REFERENCES museum.location(location_id),
	quantity INT -------ADD WITH ALTER default 1 NOT NULL -inserted measured value that cannot be negative

);

-- transaction table
CREATE TABLE IF NOT EXISTS museum.transaction (
    transaction_id SERIAL PRIMARY KEY,
    visitor_id INTEGER NOT NULL REFERENCES museum.visitor(visitor_id),
    exhibition_id INTEGER REFERENCES museum.exhibition(exhibition_id),
    transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ticket_count INTEGER NOT NULL DEFAULT 1
);

--ALTER TABLES 
--inserted value that can only be a specific value
-- Check if ENUM exists, create only if not
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'employee_position') THEN
    CREATE TYPE museum.employee_position AS ENUM ('Guide', 'Security', 'Manager');
  END IF;
END
$$;

ALTER TABLE museum.employee
ALTER COLUMN position TYPE museum.employee_position
USING position::museum.employee_position;

--date to be inserted, which must be greater than January 1, 2024
-- add check constraint for date to be more than  2024-01-01 
DO $$
BEGIN
 --to avoid duplicate type errors
  IF NOT EXISTS (
      SELECT 1 FROM pg_type WHERE typname = 'museum_event_date'
  ) THEN
    CREATE DOMAIN museum.museum_event_date AS DATE
      CHECK (VALUE > '2024-01-01');
  END IF;
END
$$;


ALTER TABLE IF EXISTS museum.exhibition
    ALTER COLUMN start_date TYPE museum.museum_event_date USING start_date::museum.museum_event_date,
    ALTER COLUMN end_date TYPE museum.museum_event_date USING end_date::museum.museum_event_date;


--inserted measured value that cannot be negative, not null
DO $$
BEGIN
    IF NOT EXISTS ( -- rerunnable
        SELECT 1 FROM pg_type WHERE typname = 'positive_quantity'
    ) THEN
        CREATE DOMAIN positive_quantity AS INTEGER
        DEFAULT 1 -- Default value 1
        CHECK (VALUE >= 0); -- Must be >= 0
    END IF;
END
$$;


-- alter column of item quantity table in locaton table 
ALTER TABLE museum.item_location
ALTER COLUMN quantity TYPE positive_quantity
USING quantity::positive_quantity;

-- Drop the column if it exists (force cleanup first)
ALTER TABLE IF EXISTS museum.exhibition
DROP COLUMN IF EXISTS is_free;

-- Then safely re-add is_free only if it does not exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'museum'
          AND table_name = 'exhibition'
          AND column_name = 'is_free'
    ) THEN
        ALTER TABLE museum.exhibition
        ADD COLUMN is_free BOOLEAN GENERATED ALWAYS AS (CASE WHEN price = 0 THEN TRUE ELSE FALSE END) STORED;
    END IF;
END
$$;


-- alter table exhibiton to set default 0 for price 
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'museum'
          AND table_name = 'exhibition'
          AND column_name = 'price'
          AND column_default IS NOT NULL
    ) THEN
        ALTER TABLE museum.exhibition
        ALTER COLUMN price SET DEFAULT 0;
    END IF;
END
$$;

--ALTER TABLE museum.item NOT NLL CONSTRAINT
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'museum'
      AND table_name = 'item'
      AND column_name = 'item_name'
      AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE museum.item
    ALTER COLUMN item_name SET NOT NULL;
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_schema = 'museum'
      AND table_name = 'visitor'
      AND constraint_name = 'uq_visitor_email'
  ) THEN
    ALTER TABLE museum.visitor
    ADD CONSTRAINT uq_visitor_email UNIQUE (email);
  END IF;
END
$$;

--INSERT VALUES TO THE TABLE
-- Insert sample locations into museum.location
DO $$
BEGIN
  WITH new_locations (location_name, description) AS (
    VALUES
      ('Main Hall', 'The central exhibition area of the museum'),
      ('Ancient Artifacts Room', 'Exhibits from ancient civilizations'),
      ('Modern Art Gallery', 'A gallery dedicated to modern art pieces'),
      ('Natural History Section', 'Displays of flora and fauna specimens'),
      ('Science and Technology Wing', 'Interactive exhibits on science and technology'),
      ('Storage Basement', 'Underground storage area for museum artifacts and exhibits')
  )
  INSERT INTO museum.location (location_name, description)
  SELECT nl.location_name, nl.description
  FROM new_locations nl
  WHERE NOT EXISTS (
    SELECT 1
    FROM museum.location ml
    WHERE LOWER(ml.location_name) = LOWER(nl.location_name)
  );
END
$$;

-- Insert sample categories into museum.category using CTE
DO $$
BEGIN
  WITH new_categories (category_name, description) AS (
    VALUES
      ('Paintings', 'All types of paintings including classical and modern art'),
      ('Sculptures', 'Various sculptures made from stone, metal, and other materials'),
      ('Ancient Artifacts', 'Artifacts from ancient civilizations and archaeological sites'),
      ('Natural History', 'Specimens related to biology, geology, and paleontology'),
      ('Photography', 'Photographic works and exhibitions'),
      ('Science and Technology', 'Scientific instruments, inventions, and technological displays')
  )
  INSERT INTO museum.category (category_name, description)
  SELECT nc.category_name, nc.description
  FROM new_categories nc
  WHERE NOT EXISTS (
    SELECT 1
    FROM museum.category c
    WHERE LOWER(c.category_name) = LOWER(nc.category_name)
  );
END
$$;
--Insert values 
WITH new_employees_temp (first_name, last_name, email, position_text) AS (
    VALUES
      ('John', 'Smith', 'john.smith@museum.com', 'Guide'),
      ('Emily', 'Jones', 'emily.jones@museum.com', 'Security'),
      ('Michael', 'Brown', 'michael.brown@museum.com', 'Manager'),
      ('Sarah', 'Wilson', 'sarah.wilson@museum.com', 'Guide'),
      ('David', 'Lee', 'david.lee@museum.com', 'Security'),
      ('Anna', 'Kim', 'anna.kim@museum.com', 'Manager')
),
new_employees AS (
    SELECT first_name, last_name, email, position_text::museum.employee_position AS position
    FROM new_employees_temp
)
INSERT INTO museum.employee (first_name, last_name, email, position)
SELECT new_emp.first_name, new_emp.last_name, new_emp.email, new_emp.position
FROM new_employees AS new_emp
WHERE NOT EXISTS (
    SELECT 1
    FROM museum.employee AS emp
    WHERE LOWER(emp.email) = LOWER(emp.email)
);


-- Insert sample visitors into museum.visitor using CTE and descriptive aliases
DO $$
BEGIN
  WITH new_visitors (first_name, last_name, email) AS (
    VALUES
      ('Alice', 'Wonderland', 'alice.wonderland@example.com'),
      ('Bob', 'Builder', 'bob.builder@example.com'),
      ('Claire', 'Redfield', 'claire.redfield@example.com'),
      ('Daniel', 'Radcliffe', 'daniel.radcliffe@example.com'),
      ('Eva', 'Green', 'eva.green@example.com'),
      ('Frank', 'Castle', 'frank.castle@example.com')
  )
  INSERT INTO museum.visitor (first_name, last_name, email)
  SELECT vis_data.first_name, vis_data.last_name, vis_data.email
  FROM new_visitors AS vis_data
  WHERE NOT EXISTS (
    SELECT 1
    FROM museum.visitor AS vis
    WHERE LOWER(vis.email) = LOWER(vis_data.email)
  );
END
$$;

-- Insert sample items into museum.item using CTE and descriptive aliases
DO $$
BEGIN
  -- Prepare new item records
  WITH new_items (item_name, category_name, description) AS (
    VALUES
      ('Starry Night Painting', 'Paintings', 'A famous painting by Vincent van Gogh.'),
      ('Ancient Egyptian Vase', 'Ancient Artifacts', 'A well-preserved vase from the Egyptian Old Kingdom period.'),
      ('Tyrannosaurus Rex Fossil', 'Natural History', 'Fossilized skeleton of a T-Rex dinosaur.'),
      ('Apollo 11 Lunar Module Replica', 'Science and Technology', 'Replica of the Apollo 11 lunar landing module.'),
      ('Auguste Rodin Sculpture', 'Sculptures', 'A marble sculpture by Auguste Rodin.'),
      ('Historic War Photography Exhibit', 'Photography', 'A collection of famous wartime photographs.')
  )
  INSERT INTO museum.item (item_name, category_id, description)
  SELECT 
    itm_data.item_name,
    (
      -- Find the matching category_id dynamically
      SELECT cat.category_id
      FROM museum.category AS cat
      WHERE LOWER(cat.category_name) = LOWER(itm_data.category_name)
      LIMIT 1
    ),
    itm_data.description
  FROM new_items AS itm_data
  WHERE NOT EXISTS (
    -- Check if item with the same name already exists (case-insensitive)
    SELECT 1
    FROM museum.item AS itm
    WHERE LOWER(itm.item_name) = LOWER(itm_data.item_name)
  );
END
$$;

-- inser values museum.exhibition 
DO $$
BEGIN
  WITH new_exhibitions (exhibition_name, start_date, end_date, is_online, url, curator_email, price_optional) AS (
    VALUES
      -- Offline exhibitions: NULL url, price specified
      ('Impressionist Art Exhibition', '2025-02-01'::date, '2025-04-01'::date, FALSE, NULL, 'john.smith@museum.com', 15.00),
      ('Photography Through the Ages', '2025-03-01'::date, '2025-06-01'::date, FALSE, NULL, 'michael.brown@museum.com', 10.00),
      ('Sculpture Masters Exhibit', '2025-04-01'::date, '2025-07-15'::date, FALSE, NULL, 'david.lee@museum.com', 20.00),
      
      -- Online exhibitions: valid URL, no price (free)
      ('Ancient Civilizations Online Exhibit', '2025-02-15'::date, '2025-05-15'::date, TRUE, 'https://museum.com/ancient-civ', 'emily.jones@museum.com', NULL),
      ('Space Exploration Virtual Tour', '2025-03-15'::date, '2025-07-01'::date, TRUE, 'https://museum.com/space-tour', 'anna.kim@museum.com', NULL),
      ('Modern Technology Showcase', '2025-04-10'::date, '2025-08-10'::date, TRUE, 'https://museum.com/tech-show', 'sarah.wilson@museum.com', NULL)
  )
  INSERT INTO museum.exhibition (exhibition_name, start_date, end_date, is_online, url, curator_id, price)
  SELECT 
    ex_data.exhibition_name,
    ex_data.start_date,
    ex_data.end_date,
    ex_data.is_online,
    CASE WHEN ex_data.is_online THEN ex_data.url ELSE NULL END, -- Only set URL if is_online=TRUE
    (
      SELECT emp.employee_id
      FROM museum.employee AS emp
      WHERE LOWER(emp.email) = LOWER(ex_data.curator_email)
      LIMIT 1
    ),
    COALESCE(ex_data.price_optional, 0) -- If price_optional is NULL, use 0 as default
  FROM new_exhibitions AS ex_data
  WHERE NOT EXISTS (
    SELECT 1
    FROM museum.exhibition AS ex
    WHERE LOWER(ex.exhibition_name) = LOWER(ex_data.exhibition_name)
  );
END
$$;

DO $$
BEGIN
  WITH exhibition_item_data (exhibition_name, item_name) AS (
    VALUES
    ('Impressionist Art', 'Starry Night'),
    ('Ancient Civilizations', 'Ancient Egyp'),
    ('Photography Through', 'Tyrannosaurus Rex'),
    ('Sculpture Masters', 'Apollo 11 Lunar Module Replica'),
    ('Space Exploration', 'Auguste Rodin'),
    ('Modern Technology', 'Historic War Photography')
  )
  INSERT INTO museum.exhibition_item (exhibition_id, item_id)
  SELECT 
    exhibition.exhibition_id, 
    item.item_id 
  FROM exhibition_item_data AS exhibition_data
  INNER JOIN museum.exhibition AS exhibition
   ON exhibition.exhibition_name ILIKE '%' || exhibition_data.exhibition_name || '%'  -- Case-insensitive matching
  INNER JOIN museum.item AS item
    ON item.item_name ILIKE '%' || exhibition_data.item_name || '%'  -- Case-insensitive matching
  WHERE NOT EXISTS (
    SELECT 1 
    FROM museum.exhibition_item 
    WHERE exhibition_id = exhibition.exhibition_id
    AND item_id = item.item_id
  );
END
$$;

select * from museum.location
select * from museum.item

-- INSERT INTO ITEM_LOCATION
DO $$
BEGIN
  WITH item_location_data (item_name, location_name) AS (
    VALUES
    ('Starry Night Painting', 'Main Hall'),
    ('Ancient Egyptian Vase', 'Ancient Artifacts Room'),
   ('Tyrannosaurus Rex Fossil',  'Modern Art Gallery'),
  ('Apollo 11 Lunar Module Replica', 'Natural History Section'),
        ('Auguste Rodin Sculpture', 'Science and Technology Wing'),
    ('Historic War Photography Exhibit', 'Storage Basement')
  )
INSERT INTO museum.item_location (item_id, location_id)  -- We omit the quantity, so it uses the default
  SELECT 
    item.item_id, 
    locat.location_id
  FROM item_location_data AS item_locat_dt
  INNER JOIN museum.item AS item
    ON LOWER(item.item_name) = LOWER(item_locat_dt.item_name)  -- Matching item names
  INNER JOIN museum.location AS locat
    ON LOWER(locat.location_name) = LOWER(item_locat_dt.location_name)  -- Matching location names
  WHERE NOT EXISTS (
    SELECT 1 
    FROM museum.item_location AS il
    WHERE il.item_id = item.item_id 
    AND il.location_id = locat.location_id
  );
END
$$;

-- add data transaction table
DO $$ 
BEGIN
  WITH transaction_data (visitor_email, exhibition_name, ticket_count) AS (
    VALUES
      ('alice.wonderland@example.com', 'Impressionist Art Exhibition', 1),
      ('bob.builder@example.com', 'Photography Through the Ages', 1),
      ('claire.redfield@example.com', 'Sculpture Masters Exhibit', 1),
      ('daniel.radcliffe@example.com', 'Ancient Civilizations Online Exhibit', 1),
      ('eva.green@example.com', 'Space Exploration Virtual Tour', 1),
      ('frank.castle@example.com', 'Modern Technology Showcase', 1)
  )
  INSERT INTO museum.transaction (visitor_id, exhibition_id, ticket_count)
  SELECT 
    visitor.visitor_id,
    exhibition.exhibition_id,
    transaction_data.ticket_count
  FROM transaction_data
  INNER JOIN museum.visitor AS visitor
    ON LOWER(visitor.email) = LOWER(transaction_data.visitor_email)  -- Match email case-insensitively
  INNER JOIN museum.exhibition AS exhibition
    ON LOWER(exhibition.exhibition_name) = LOWER(transaction_data.exhibition_name)  -- Match exhibition name case-insensitively
  WHERE NOT EXISTS (
    SELECT 1
    FROM museum.transaction AS tp
    WHERE tp.visitor_id = visitor.visitor_id
    AND tp.exhibition_id = exhibition.exhibition_id
  );
END
$$;


--5. Create the following functions.
--5.1 Create a function that updates data in one of your tables. This function should take the following input arguments:
-- The primary key value of the row you want to update
-- The name of the column you want to update
-- The new value you want to set for the specified column

-- This function should be designed to modify the specified row in the table, updating the specified column with the new value.

CREATE OR REPLACE FUNCTION update_visitor_data(
  p_visitor_id INTEGER,      -- The visitor's primary key (ID) to update
  p_column_name TEXT,        -- The name of the column to update
  p_new_value TEXT           -- The new value to set for the specified column
)
RETURNS VOID AS $$
DECLARE
  dynamic_query TEXT;        -- To hold the dynamic SQL query
BEGIN
  -- Construct the dynamic SQL query
  dynamic_query := 'UPDATE museum.visitor ' ||
                  'SET ' || p_column_name || ' = $1 ' ||
                  'WHERE visitor_id = $2';

  -- Execute the dynamic query with the specified new value and visitor_id
  EXECUTE dynamic_query USING p_new_value, p_visitor_id;

  -- Optionally, raise a notice to confirm the update
  RAISE NOTICE 'Updated visitor_id %: Set % = %', p_visitor_id, p_column_name, p_new_value;
END
$$ LANGUAGE plpgsql;


--------------5.2
--
-- 1. First explicitly drop existing function with full signature
DROP FUNCTION IF EXISTS add_transaction(INTEGER, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS add_transaction_by_email_exhibition;

-- 2. Create new function with proper parameters

CREATE OR REPLACE FUNCTION add_transaction_by_email_exhibition(
    p_email VARCHAR(255),             -- Email of the visitor
    p_exhibition_name VARCHAR(255),   -- Name of the exhibition
    p_ticket_count INTEGER DEFAULT 1  -- Number of tickets purchased (default to 1)
)
RETURNS VOID AS $$
DECLARE
    v_visitor_id INTEGER;
    v_exhibition_id INTEGER;
BEGIN
    -- Look up the visitor ID based on email
    SELECT visitor_id INTO v_visitor_id
    FROM museum.visitor
    WHERE email = p_email
    LIMIT 1;

    -- If visitor not found, raise an error
    IF v_visitor_id IS NULL THEN
        RAISE EXCEPTION 'Visitor with email "%" not found', p_email;
    END IF;

    -- Look up the exhibition ID based on the exhibition name
    SELECT exhibition_id INTO v_exhibition_id
    FROM museum.exhibition
    WHERE exhibition_name = p_exhibition_name
    LIMIT 1;

    -- If exhibition not found, raise an error
    IF v_exhibition_id IS NULL THEN
        RAISE EXCEPTION 'Exhibition with name "%" not found', p_exhibition_name;
    END IF;

    -- Insert the transaction into the transaction table
    INSERT INTO museum.transaction (visitor_id, exhibition_id, ticket_count)
    VALUES (v_visitor_id, v_exhibition_id, p_ticket_count);

    --  add a message or log to confirm success
    RAISE NOTICE 'Transaction added successfully for email "%", exhibition "%", ticket_count %',
        p_email, p_exhibition_name, p_ticket_count;
END;
$$ LANGUAGE plpgsql;
--  Example valid calls:
SELECT add_transaction_by_email_exhibition('bob.builder@example.com', 'Impressionist Art Exhibition', 3);
--6. Create a view that presents analytics for the most recently added quarter in your database. Ensure that the result excludes irrelevant fields such as surrogate keys and duplicate entries.

CREATE VIEW recent_quarter_exhibition_analytics AS
SELECT 
    ex.exhibition_name AS "Exhibition Name",
    COUNT(*) AS "Total Tickets Sold",
    COUNT(DISTINCT trans.visitor_id) AS "Number of Unique Visitors",
    CONCAT('Q', EXTRACT(QUARTER FROM trans.transaction_date), ' ', EXTRACT(YEAR FROM trans.transaction_date)) AS "Quarter"
FROM museum.transaction AS trans
JOIN museum.exhibition AS ex 
    ON trans.exhibition_id = ex.exhibition_id
WHERE EXTRACT(YEAR FROM trans.transaction_date) = (
        SELECT EXTRACT(YEAR FROM MAX(transaction_date)) 
        FROM museum.transaction
    )
  AND EXTRACT(QUARTER FROM trans.transaction_date) = (
        SELECT EXTRACT(QUARTER FROM MAX(transaction_date)) 
        FROM museum.transaction
    )
GROUP BY ex.exhibition_name, EXTRACT(YEAR FROM trans.transaction_date), EXTRACT(QUARTER FROM trans.transaction_date);

--7. Create a read-only role for the manager. This role should have permission to perform SELECT queries on the database tables, and also be able to log in. Please ensure that you adhere to best practices for database security when defining this role
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'manager') THEN
        -- 1. Create role manager with login and encrypted password
        CREATE ROLE manager WITH LOGIN ENCRYPTED PASSWORD 'password';

        -- 2. Grant usage on the museum schema
        GRANT USAGE ON SCHEMA museum TO manager;

        -- 3. Grant SELECT on all existing tables in the museum schema
        GRANT SELECT ON ALL TABLES IN SCHEMA museum TO manager;

        -- 4. Ensure future tables in the museum schema grant SELECT to manager
        ALTER DEFAULT PRIVILEGES IN SCHEMA museum
          GRANT SELECT ON TABLES TO manager;

        -- 5. Explicitly revoke any data-modification privileges
        REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA museum FROM manager;
        REVOKE CREATE ON SCHEMA museum FROM manager;
    END IF;
END $$;
