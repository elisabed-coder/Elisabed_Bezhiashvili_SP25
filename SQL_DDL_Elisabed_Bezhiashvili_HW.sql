DROP database if exists social_media
--cant se do block cause create database must execute as a standalone component
CREATE DATABASE social_media
    WITH OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en-US'
    LC_CTYPE = 'en-US'
    LOCALE_PROVIDER = 'libc'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = false;


--Create new schema if not exisits;
CREATE SCHEMA if NOT EXISTS social_data;

--define Domain for positive valid timestamp for fields
DO $$
BEGIN
 --to avoid duplicate type errors
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'valid_timestamp_after_2000'
    ) THEN
        CREATE DOMAIN valid_timestamp_after_2000 AS TIMESTAMP
		--Ensures a timestamp is later than Jan 1, 2000
        CHECK (VALUE > TIMESTAMP '2000-01-01 00:00:00');
    END IF;
END
$$;

--rerunable positive integer domain
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'positive_integer'
    ) THEN
        CREATE DOMAIN positive_integer AS INTEGER
		--add default value 
        DEFAULT 0
		-- Enforce non-negative integer values 
        CHECK (VALUE >= 0);
    END IF;
END
$$;

-- Create enum type for roles
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'user_role'
    ) THEN
	-- Predefined list of roles for users
        CREATE TYPE user_role AS ENUM ('Doctor', 'Student', 'Researcher');
    END IF;
END
$$;

-- Create enum type for visibility
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'visibility_type'
    ) THEN
		-- Predefined list for groups
        CREATE TYPE visibility_type AS ENUM ('public', 'private');
    END IF;
END
$$;

-- Create enum type for member_role
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'member_role'
    ) THEN
        CREATE TYPE member_role AS ENUM ('Admin', 'Moderator', 'Member');
    END IF;
END
$$;

-- Create enum type for reaction_type
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'reaction_type'
    ) THEN
        CREATE TYPE reaction_type AS ENUM ('Like', 'Love', 'Haha', 'Wow', 'Sad', 'Angry');
    END IF;
END
$$;

-- Create enum type for friendship_status
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'friendship_status'
    ) THEN
		CREATE TYPE friendship_status AS ENUM ('pending', 'accepted', 'blocked');
    END IF;
END
$$;

-- CREATE TABLE geolocation --to ensure critical fields are always filled out added not null 
CREATE TABLE IF NOT EXISTS social_data.geolocation (
	geolocation_id serial PRIMARY KEY,
	latitude DECIMAL(9, 6) NOT NULL,
	longitude DECIMAL(9, 6) NOT NULL,
	country VARCHAR(255) NOT NULL,
	city VARCHAR(255) NOT NULL
);

-- CREATE TABLE users
CREATE TABLE IF NOT EXISTS social_data.users (
	user_id serial PRIMARY KEY,
	email VARCHAR(255) UNIQUE NOT NULL,
	password VARCHAR(255) NOT NULL,
	role user_role NOT NULL,
	fullname VARCHAR(255) NOT NULL,
	created_at valid_timestamp_after_2000 NOT NULL DEFAULT current_timestamp,
	updated_at valid_timestamp_after_2000 NOT NULL DEFAULT current_timestamp,
	geolocation_id INT,
	CONSTRAINT fk_geolocation FOREIGN key (geolocation_id) REFERENCES social_data.geolocation (geolocation_id)
);

-- add unique to user_id to make sure its one-to-one relationship, NOT NULL ensures that every profile is associated with a real user.
CREATE TABLE IF NOT EXISTS social_data.user_profile (
	profile_id serial PRIMARY KEY,
	user_id INT UNIQUE NOT NULL,
	specialty VARCHAR(255),
	license_number positive_integer UNIQUE, -- To make sure I use positive integer,I changed data-type to int.
	bio TEXT,
	profile_picture TEXT,
	CONSTRAINT fk_user FOREIGN key (user_id) REFERENCES social_data.users (user_id)
);

CREATE TABLE IF NOT EXISTS social_data.groups (
	group_id serial PRIMARY KEY,
	group_name VARCHAR(255) NOT NULL UNIQUE,
	description TEXT,
	created_at valid_timestamp_after_2000 NOT NULL DEFAULT current_timestamp,
	visibility visibility_type NOT NULL DEFAULT 'public'
);

CREATE TABLE IF NOT EXISTS social_data.group_members (
	member_id serial PRIMARY KEY,
	group_id INT NOT NULL,
	user_id INT NOT NULL,
	joined_at valid_timestamp_after_2000 NOT NULL DEFAULT current_timestamp,
	role member_role NOT NULL DEFAULT 'Member',
	CONSTRAINT fk_group FOREIGN key (group_id) REFERENCES social_data.groups (group_id),
	CONSTRAINT fk_user FOREIGN key (user_id) REFERENCES social_data.users (user_id)
);

CREATE TABLE IF NOT EXISTS social_data.posts (
	post_id serial PRIMARY KEY,
	user_id INT NOT NULL,
	post_content TEXT,
	media_url VARCHAR(255),
	group_id INT,
	created_at valid_timestamp_after_2000 NOT NULL DEFAULT current_timestamp,
	updated_at valid_timestamp_after_2000 NOT NULL DEFAULT current_timestamp,
	CONSTRAINT fk_user FOREIGN key (user_id) REFERENCES social_data.users (user_id),
	CONSTRAINT fk_group FOREIGN key (group_id) REFERENCES social_data.groups (group_id)
);

CREATE TABLE IF NOT EXISTS social_data.post_comments (
	comment_id serial PRIMARY KEY,
	post_id INT NOT NULL,
	user_id INT NOT NULL,
	comment_content TEXT,
	created_at valid_timestamp_after_2000 NOT NULL DEFAULT current_timestamp,
	updated_at valid_timestamp_after_2000 NOT NULL DEFAULT current_timestamp,
	CONSTRAINT fk_post FOREIGN key (post_id) REFERENCES social_data.posts (post_id),
	CONSTRAINT fk_user FOREIGN key (user_id) REFERENCES social_data.users (user_id)
);

CREATE TABLE IF NOT EXISTS social_data.post_reactions (
	reaction_id serial PRIMARY KEY,
	post_id INT NOT NULL,
	user_id INT NOT NULL,
	reaction_type reaction_type NOT NULL,
	created_at TIMESTAMP DEFAULT current_timestamp,
	CONSTRAINT fk_post FOREIGN key (post_id) REFERENCES social_data.posts (post_id),
	CONSTRAINT fk_user FOREIGN key (user_id) REFERENCES social_data.users (user_id)
);

CREATE TABLE IF NOT EXISTS social_data.comment_reactions (
	comment_reaction_id serial PRIMARY KEY,
	comment_id INT NOT NULL,
	user_id INT NOT NULL,
	reaction_type reaction_type NOT NULL,
	created_at TIMESTAMP DEFAULT current_timestamp,
	updated_at TIMESTAMP DEFAULT current_timestamp,
	CONSTRAINT fk_comment FOREIGN key (comment_id) REFERENCES social_data.post_comments (comment_id),
	CONSTRAINT fk_user FOREIGN key (user_id) REFERENCES social_data.users (user_id)
);

CREATE TABLE IF NOT EXISTS social_data.post_share (
	share_id serial PRIMARY KEY,
	post_id INT NOT NULL,
	user_id INT NOT NULL,
	created_at valid_timestamp_after_2000 NOT NULL DEFAULT current_timestamp,
	CONSTRAINT fk_post FOREIGN key (post_id) REFERENCES social_data.posts (post_id),
	CONSTRAINT fk_user FOREIGN key (user_id) REFERENCES social_data.users (user_id)
);

-- add constraint to make sure user pair is not duplicated in the table and user cant be friend to himself.
CREATE TABLE IF NOT EXISTS social_data.friendship (
	friendship_id serial PRIMARY KEY,
	user_id_1 INT NOT NULL,
	user_id_2 INT NOT NULL,
	status friendship_status NOT NULL,
	created_at TIMESTAMP DEFAULT current_timestamp,
	updated_at TIMESTAMP DEFAULT current_timestamp,
	normalized_user_1 INT generated always AS (LEAST(user_id_1, user_id_2)) stored,
	normalized_user_2 INT generated always AS (GREATEST(user_id_1, user_id_2)) stored,
	CONSTRAINT fk_user_1 FOREIGN key (user_id_1) REFERENCES social_data.users (user_id),
	CONSTRAINT fk_user_2 FOREIGN key (user_id_2) REFERENCES social_data.users (user_id),
	CONSTRAINT unique_friendship UNIQUE (normalized_user_1, normalized_user_2),
	CONSTRAINT check_not_self_friendship CHECK (user_id_1!=user_id_2)
);

CREATE TABLE IF NOT EXISTS social_data.follows (
	following_id serial PRIMARY KEY,
	follower_id INT NOT NULL,
	followed_id INT NOT NULL,
	created_at TIMESTAMP DEFAULT current_timestamp,
	CONSTRAINT fk_follower FOREIGN key (follower_id) REFERENCES social_data.users (user_id),
	CONSTRAINT fk_followed FOREIGN key (followed_id) REFERENCES social_data.users (user_id)
);

-- Function to automatically update the 'updated_at' column when a row is modified
-- This is useful for tracking the last modification time of the record without 
DO $$
BEGIN
    -- Check if the function exists before creating
    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc -- this contains all functions
        WHERE proname = 'update_modified_column'
          AND pg_function_is_visible(oid)
    ) THEN
		--create function only if ti does not exists
        CREATE FUNCTION update_modified_column() RETURNS trigger AS $func$
        BEGIN
			-- Set the 'updated_at' field of the updated row to the current timestamp
            NEW.updated_at = CURRENT_TIMESTAMP;
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;
    END IF;
END$$;

-- Helper block to create triggers only if they don't exist
DO $$
DECLARE
    trigger_exists BOOLEAN; -- declare variable to check if the trigger already exists 
BEGIN
    -- USERS TABLE
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger --contains all triggers
        WHERE tgname = 'update_users_modtime'
    ) INTO trigger_exists; --store the reuslt in this variable , true or false
    IF NOT trigger_exists THEN
        CREATE TRIGGER update_users_modtime
        BEFORE UPDATE ON social_data.users
        FOR EACH ROW -- Apply the trigger to each row affected by the update
        EXECUTE FUNCTION update_modified_column();
    END IF;

-- Create trigger for posts table
 SELECT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'update_posts_modtime'
    ) INTO trigger_exists;
    IF NOT trigger_exists THEN
        CREATE TRIGGER update_posts_modtime
        BEFORE UPDATE ON social_data.posts
        FOR EACH ROW
        EXECUTE FUNCTION update_modified_column();
    END IF;

 -- POST_COMMENTS TABLE
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'update_post_comments_modtime'
    ) INTO trigger_exists;
    IF NOT trigger_exists THEN
        CREATE TRIGGER update_post_comments_modtime
        BEFORE UPDATE ON social_data.post_comments
        FOR EACH ROW
        EXECUTE FUNCTION update_modified_column();
    END IF;

-- Create trigger for comment_reactions table
 SELECT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'update_comment_reactions_modtime'
    ) INTO trigger_exists;
    IF NOT trigger_exists THEN
        CREATE TRIGGER update_comment_reactions_modtime
        BEFORE UPDATE ON social_data.comment_reactions
        FOR EACH ROW
        EXECUTE FUNCTION update_modified_column();
    END IF;
END$$;

--INSERT DATA INTO THE TABLES;
INSERT INTO
	social_data.geolocation (latitude, longitude, country, city)
SELECT
	*
FROM
	(
		VALUES
			(40.7128, -74.0060, 'USA', 'New York'),
			(51.5074, -0.1278, 'UK', 'London')
	) AS geo (latitude, longitude, country, city)
WHERE
	NOT EXISTS (
		SELECT
			1
		FROM
			social_data.geolocation g
		WHERE
			g.latitude=geo.latitude AND
			g.longitude=geo.longitude
	)
RETURNING
*;

-- Insert users with a random geolocation, use do nothing to make sure query is reusable and rerunnable, also add for geolocation field use random function to make sure IDs are not hardcored. 
WITH
	random_geolocation AS (
		SELECT
			geolocation_id
		FROM
			social_data.geolocation
		ORDER BY
			RANDOM()
		LIMIT
			2
	),
	user_entries AS (
		SELECT
			'john@gmail.com',
			'password1',
			'Doctor'::user_role,
			'John Doe',
			(
				SELECT
					geolocation_id
				FROM
					random_geolocation
				LIMIT
					1
			)
		UNION ALL
		SELECT
			'vlad@gmail.com',
			'password2',
			'Researcher'::user_role,
			'Vladimer Williams',
			(
				SELECT
					geolocation_id
				FROM
					random_geolocation
				OFFSET
					1
				LIMIT
					1
			)
		UNION ALL
		SELECT
			'sarah@gmail.com',
			'password3',
			'Student'::user_role,
			'Sarah Miller',
			(
				SELECT
					geolocation_id
				FROM
					random_geolocation
				OFFSET
					1
				LIMIT
					1
			)
		UNION ALL
		SELECT
			'Magdalena@gmail.com',
			'password5',
			'Student'::user_role,
			'Magdalena Kunnis',
			(
				SELECT
					geolocation_id
				FROM
					random_geolocation
				OFFSET
					1
				LIMIT
					1
			)
	)
INSERT INTO
	social_data.users (email, password, role, fullname, geolocation_id)
SELECT
	*
FROM
	user_entries
ON CONFLICT (email) DO NOTHING
RETURNING
*;

-- Insert user profiles run
INSERT INTO
	social_data.user_profile (
		user_id,
		specialty,
		license_number,
		bio,
		profile_picture
	)
SELECT
	user_id,
	'Cardiologist',
	123456,
	'Experienced cardiologist with a focus on heart disease research.',
	'path/to/profile_picture1.jpg'
FROM
	social_data.users
WHERE
	email='john@gmail.com' AND
	NOT EXISTS (
		SELECT
			1
		FROM
			social_data.user_profile
		WHERE
			user_id=social_data.users.user_id
	)
RETURNING
*;

INSERT INTO
	social_data.user_profile (
		user_id,
		specialty,
		license_number,
		bio,
		profile_picture
	)
SELECT
	user_id,
	'Neurologist',
	789012,
	'Neurologist specializing in brain injuries.',
	'path/to/profile_picture2.jpg'
FROM
	social_data.users
WHERE
	email='vlad@gmail.com' AND
	NOT EXISTS (
		SELECT
			1
		FROM
			social_data.user_profile
		WHERE
			user_id=social_data.users.user_id
	)
RETURNING
*;

-- Insert user profiles run
WITH
	new_profiles AS ( -- start with CTE  for new profiles data
		SELECT
			users.user_id,
			'Cardiologist' AS specialty,
			123456 AS license_number,
			'Experienced cardiologist with a focus on heart disease research.' AS bio,
			'path/to/profile_picture1.jpg' AS profile_picture
		FROM
			social_data.users AS users
		WHERE
			users.email='john@gmail.com' AND
			NOT EXISTS (
				SELECT
					1
				FROM
					social_data.user_profile AS profile
				WHERE
					profile.user_id=users.user_id
			)
		UNION ALL --combine result with another select statement
		SELECT
			users.user_id,
			'Neurologist',
			789012,
			'Neurologist specializing in brain injuries.',
			'path/to/profile_picture2.jpg'
		FROM
			social_data.users AS users
		WHERE
			users.email='vlad@gmail.com' AND
			NOT EXISTS (
				SELECT
					1
				FROM
					social_data.user_profile AS profile
				WHERE
					profile.user_id=users.user_id
			)
	)
INSERT INTO
	social_data.user_profile (
		user_id,
		specialty,
		license_number,
		bio,
		profile_picture
	)
SELECT
	*
FROM
	new_profiles
RETURNING
*;

-- Add data to the groups table
WITH
	new_group AS (
		SELECT
			'Health Professionals' AS group_name,
			'A group for doctors and healthcare professionals.' AS description,
			'public'::visibility_type AS visibility
		WHERE
			NOT EXISTS (
				SELECT
					1
				FROM
					social_data.groups
				WHERE
					group_name='Health Professionals'
			)
		UNION ALL
		SELECT
			'Doctors' AS group_name,
			'A group for doctors.' AS description,
			'public'::visibility_type AS visibility
		WHERE
			NOT EXISTS (
				SELECT
					1
				FROM
					social_data.groups
				WHERE
					group_name='Doctors'
			)
	)
INSERT INTO
	social_data.groups (group_name, description, visibility)
SELECT
	*
FROM
	new_group
RETURNING
*;

-- insert data into group memebers
INSERT INTO
	social_data.group_members (group_id, user_id, role)
SELECT
	groups.group_id,
	users.user_id,
	'Member'::member_role
FROM
	social_data.groups AS groups
	CROSS JOIN social_data.users AS users
WHERE
	groups.group_name='Health Professionals' AND
	users.email IN ('john@gmail.com', 'vlad@gmail.com') AND
	NOT EXISTS ( -- To ensure no duplicates
		SELECT
			1
		FROM
			social_data.group_members AS members
		WHERE
			members.group_id=groups.group_id AND
			members.user_id=users.user_id
	)
RETURNING
	member_id,
	group_id,
	user_id;

--Insert data to the posts table
WITH
	insert_post_data AS (
		-- Insert first post for john@gmail.com into Health Professionals group
		SELECT
			users.user_id,
			'This is a post about health and wellness.' AS post_content,
			'https://example.com/image1.jpg' AS media_url,
			groups.group_id
		FROM
			social_data.users AS users
			INNER JOIN social_data.groups AS groups ON groups.group_name='Health Professionals'
		WHERE
			users.email='john@gmail.com'
		UNION ALL
		-- Insert second post for vlad@gmail.com into Researchers group
		SELECT
			users.user_id,
			'Advancements in medical AI are changing the game.' AS post_content,
			'https://example.com/image2.jpg' AS media_url,
			groups.group_id
		FROM
			social_data.users AS users
			INNER JOIN social_data.groups AS groups ON groups.group_name='Doctors'
		WHERE
			LOWER(users.email)='vlad@gmail.com'
	)
	-- Insert the data into the posts table using the CTE
INSERT INTO
	social_data.posts (user_id, post_content, media_url, group_id)
SELECT
	user_id,
	post_content,
	media_url,
	group_id
FROM
	insert_post_data
WHERE
	NOT EXISTS (
		SELECT
			1
		FROM
			social_data.posts AS posts
		WHERE
			posts.user_id=insert_post_data.user_id AND
			posts.group_id=insert_post_data.group_id AND
			posts.post_content=insert_post_data.post_content
	)
RETURNING
	post_id,
	user_id,
	group_id;

-- insert data in comments and comment_reactions
WITH
	inserted_comments AS (
		INSERT INTO
			social_data.post_comments (post_id, user_id, comment_content)
		SELECT
			posts.post_id,
			users.user_id,
			comment_content
		FROM
			social_data.posts AS posts
			INNER JOIN social_data.users AS users ON LOWER(users.email)='vlad@gmail.com'
			CROSS JOIN (
				VALUES
					('Thanks for sharing this!')
			) AS comment (comment_content)
		WHERE
			posts.post_content='This is a post about health and wellness.' AND
			NOT EXISTS (
				SELECT
					1
				FROM
					social_data.post_comments AS post_comments
				WHERE
					post_comments.post_id=posts.post_id AND
					post_comments.user_id=users.user_id AND
					post_comments.comment_content=comment.comment_content
			)
		UNION ALL
		SELECT
			posts.post_id,
			users.user_id,
			'Interesting perspective, thanks!' AS comment_content
		FROM
			social_data.posts AS posts
			INNER JOIN social_data.users AS users ON users.email='john@gmail.com'
			CROSS JOIN (
				VALUES
					('Interesting perspective, thanks!')
			) AS comment (comment_content)
		WHERE
			posts.post_content='Advancements in medical AI are changing the game.' AND
			NOT EXISTS (
				SELECT
					1
				FROM
					social_data.post_comments AS post_comments
				WHERE
					post_comments.post_id=posts.post_id AND
					post_comments.user_id=users.user_id AND
					post_comments.comment_content=comment.comment_content
			)
		RETURNING
			comment_id,
			user_id,
			comment_content
	)
INSERT INTO
	social_data.comment_reactions (comment_id, user_id, reaction_type)
SELECT
	inserted_comm.comment_id,
	users.user_id,
	'Haha'::reaction_type
FROM
	inserted_comments AS inserted_comm
	INNER JOIN social_data.users ON users.email='john@gmail.com'
WHERE
	inserted_comm.comment_content='Thanks for sharing this!'
UNION ALL
SELECT
	inserted_comm.comment_id,
	users.user_id,
	'Wow'::reaction_type
FROM
	inserted_comments AS inserted_comm
	INNER JOIN social_data.users ON users.email='vlad@gmail.com'
WHERE
	inserted_comm.comment_content='Interesting perspective, thanks!' AND
	NOT EXISTS (
		SELECT
			1
		FROM
			social_data.comment_reactions AS comm_react
		WHERE
			comm_react.comment_id=inserted_comm.comment_id AND
			comm_react.user_id=users.user_id AND
			comm_react.reaction_type='Wow'
	);

--insert data in post reactions
WITH
	inserted_comments AS (
		-- Insert comments with the correct content if they don't exist already
		INSERT INTO
			social_data.post_comments (post_id, user_id, comment_content)
		SELECT
			posts.post_id,
			users.user_id,
			comment_content
		FROM
			social_data.posts AS posts
			INNER JOIN social_data.users AS users ON users.email='vlad@gmail.com'
			CROSS JOIN (
				VALUES
					('Thanks for sharing this!')
			) AS comment (comment_content)
		WHERE
			posts.post_content='This is a post about health and wellness.' AND
			NOT EXISTS (
				SELECT
					1
				FROM
					social_data.post_comments AS post_comments
				WHERE
					post_comments.post_id=posts.post_id AND
					post_comments.user_id=users.user_id AND
					post_comments.comment_content=comment.comment_content
			)
		UNION ALL
		SELECT
			posts.post_id,
			users.user_id,
			comment_content
		FROM
			social_data.posts AS posts
			INNER JOIN social_data.users AS users ON users.email='john@gmail.com'
			CROSS JOIN (
				VALUES
					('Interesting perspective, thanks!')
			) AS comment (comment_content)
		WHERE
			posts.post_content='Advancements in medical AI are changing the game.' AND
			NOT EXISTS (
				SELECT
					1
				FROM
					social_data.post_comments AS post_comments
				WHERE
					post_comments.post_id=posts.post_id AND
					post_comments.user_id=users.user_id AND
					post_comments.comment_content=comment.comment_content
			)
		RETURNING
			comment_id,
			user_id,
			comment_content
	)
SELECT
	*
FROM
	inserted_comments;

-- Insert reactions to comments if they don't exist already
WITH
	reaction_data AS (
		-- Define the data to insert: post_id, user_id, and reaction_type
		SELECT
			posts.post_id,
			users.user_id,
			'Wow'::reaction_type AS reaction_type
		FROM
			social_data.posts AS posts
			INNER JOIN social_data.users AS users ON (
				users.email='vlad@gmail.com' AND
				posts.post_content='This is a post about health and wellness.'
			)
		UNION ALL
		SELECT
			posts.post_id,
			users.user_id,
			'Love'::reaction_type
		FROM
			social_data.posts AS posts
			INNER JOIN social_data.users AS users ON users.email='john@gmail.com'
		WHERE
			posts.post_content='Advancements in medical AI are changing the game.'
	),
	-- Insert the reactions, ensuring they do not already exist
	inserted_post_reactions AS (
		INSERT INTO
			social_data.post_reactions (post_id, user_id, reaction_type)
		SELECT
			reaction_data.post_id,
			reaction_data.user_id,
			reaction_data.reaction_type
		FROM
			reaction_data
		WHERE
			NOT EXISTS (
				SELECT
					1
				FROM
					social_data.post_reactions AS existing_post_reaction
				WHERE
					existing_post_reaction.post_id=reaction_data.post_id AND
					existing_post_reaction.user_id=reaction_data.user_id AND
					existing_post_reaction.reaction_type=reaction_data.reaction_type
			)
		RETURNING
			post_id,
			user_id,
			reaction_type
	)
	-- Select the rows that were inserted
SELECT
	*
FROM
	inserted_post_reactions;

--Insert post_share data 
WITH
	share_data AS (
		SELECT
			posts.post_id,
			users.user_id
		FROM
			social_data.posts AS posts
			INNER JOIN social_data.users AS users ON users.email='vlad@gmail.com'
		WHERE
			LOWER(posts.post_content)='this is a post about health and wellness.'
		UNION ALL
		SELECT
			posts.post_id,
			users.user_id
		FROM
			social_data.posts AS posts
			INNER JOIN social_data.users AS users ON users.email='john@gmail.com'
		WHERE
			LOWER(posts.post_content)='advancements in medical ai are changing the game.'
	),
	inserted_shares AS (
		INSERT INTO
			social_data.post_share (post_id, user_id)
		SELECT
			share_data.post_id,
			share_data.user_id
		FROM
			share_data
		WHERE
			NOT EXISTS (
				SELECT
					1
				FROM
					social_data.post_share AS existing_share
				WHERE
					existing_share.post_id=share_data.post_id AND
					existing_share.user_id=share_data.user_id
			)
		RETURNING
			share_id,
			post_id,
			user_id,
			created_at
	)
SELECT
	*
FROM
	inserted_shares;

-- Insert rows in freindship table
WITH
	friendship_data AS (
		-- Define TWO distinct friendship pairs using email addresses
		SELECT
			u1.user_id AS user_id_1,
			u2.user_id AS user_id_2,
			'pending'::friendship_status AS status
		FROM
			social_data.users u1,
			social_data.users u2
		WHERE
			u1.email='vlad@gmail.com' AND
			u2.email='john@gmail.com'
		UNION ALL
		SELECT
			u1.user_id AS user_id_1,
			u2.user_id AS user_id_2,
			'accepted'::friendship_status AS status
		FROM
			social_data.users u1,
			social_data.users u2
		WHERE
			u1.email='sarah@gmail.com' AND
			u2.email='vlad@gmail.com'
	),
	-- Insert the friendships with conflict handling
	upserted_friendships AS (
		INSERT INTO
			social_data.friendship (user_id_1, user_id_2, status)
		SELECT
			fd.user_id_1,
			fd.user_id_2,
			fd.status
		FROM
			friendship_data fd
		ON CONFLICT (normalized_user_1, normalized_user_2) DO NOTHING
		RETURNING
			friendship_id,
			user_id_1,
			user_id_2,
			status,
			created_at,
			updated_at
	)
	-- Select the rows that were inserted
SELECT
	*
FROM
	upserted_friendships;

--Insert rows in followers
WITH
	followers_data AS (
		-- Define TWO distinct friendship pairs using email addresses
		SELECT
			u1.user_id AS user_id_1,
			u2.user_id AS user_id_2
		FROM
			social_data.users u1,
			social_data.users u2
		WHERE
			u1.email='vlad@gmail.com' AND
			u2.email='john@gmail.com'
		UNION ALL
		SELECT
			u1.user_id AS user_id_1,
			u2.user_id AS user_id_2
		FROM
			social_data.users u1,
			social_data.users u2
		WHERE
			u1.email='sarah@gmail.com' AND
			u2.email='vlad@gmail.com'
	),
	-- Insert the follows with conflict handling
	upserted_followers AS (
		INSERT INTO
			social_data.follows (follower_id, followed_id)
		SELECT
			fd.user_id_1,
			fd.user_id_2
		FROM
			followers_data fd
		WHERE
			NOT EXISTS (
				SELECT
					1
				FROM
					social_data.follows f
				WHERE
					f.follower_id=fd.user_id_1 AND
					f.followed_id=fd.user_id_2
			)
		RETURNING
			following_id,
			follower_id,
			followed_id,
			created_at
	)
	-- Select the rows that were inserted
SELECT
	*
FROM
	upserted_followers;

-- Add 'record_ts' column if it doesn't exist

DO $$
DECLARE
    table_name text; --Variable to hold the name of each table during iteration
BEGIN
    FOR table_name IN 
        SELECT t.table_name
        FROM information_schema.tables t
        WHERE t.table_schema = 'social_data'
        AND t.table_name IN (
            'users', 'groups', 'group_members', 'posts', 'geolocation',
            'user_profile', 'post_share', 'post_comments', 'post_reactions',
            'follows', 'comment_reactions', 'friendship'
        )
    LOOP
	--dynamically execute alter table command for tables. with help of if only column does not exist. 
        EXECUTE format(
            'ALTER TABLE social_data.%I ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;',
            table_name
        );
    END LOOP;
END $$;

-- use loop function to reduce reduncdance
DO $$ 
DECLARE
    table_name text;
BEGIN
    -- List of tables to update
    FOR table_name IN 
        SELECT t.table_name 
        FROM information_schema.tables t
        WHERE t.table_schema = 'social_data' AND 
              t.table_name IN (
                  'users', 'groups', 'group_members', 'posts', 'geolocation',
                  'user_profile', 'post_share', 'post_comments', 'post_reactions',
                  'follows', 'comment_reactions', 'friendship'
              )
    LOOP
		--dynamically execute alter table command for tables. with help of if only column does not exist. 

        EXECUTE format(
            'UPDATE social_data.%I SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;',
            table_name
        );
    END LOOP;
END $$;

SELECT
	*
FROM
	social_data.group_members;



	