/* 01 - 01 - Using Non-Caching Views to Select Data*/
/* 1. Create a view to simplify access to the data produced by the
following queries (see Task 4 in “JOINs with MIN, MAX, AVG,
range”)..*/
CREATE OR REPLACE VIEW first_book AS /* Just add this line to the beginning of the query*/
SELECT s_id, s_name, b_name
FROM (SELECT subscriptions.sb_subscriber, sb_book
	FROM subscriptions
    JOIN (SELECT subscriptions.sb_subscriber,
				MIN(sb_id) AS min_sb_id
			FROM subscriptions
            JOIN (SELECT sb_subscriber, MIN(sb_start) AS min_sb_start
				FROM subscriptions
                GROUP BY sb_subscriber) AS step_1
			ON subscriptions.sb_subscriber = step_1.sb_subscriber
            AND subscriptions.sb_start = step_1.min_sb_start
		GROUP BY subscriptions.sb_subscriber, min_sb_start) AS step_2
	ON subscriptions.sb_id = step_2.min_sb_id) AS step_3
JOIN subscribers ON sb_subscriber = s_id
JOIN books ON sb_book = b_id;
/* The result would be achiveable via query:*/
SELECT *
FROM first_book;

/* 2. Create a view to show authors along with their books quantity
taking into account only authors with two or more books.*/
CREATE OR REPLACE VIEW authors_with_more_than_one_book AS
SELECT a_id, a_name, COUNT(b_id) AS books_in_library
FROM authors
JOIN m2m_books_authors USING (a_id)
GROUP BY a_id
HAVING books_in_library > 1;

SELECT *
FROM authors_with_more_than_one_book;

/* 02 - Using Caching Views and Tables to Select Data*/
/* 3. Create a view to speed up the retrieval of the following data:
- total books count;
- taken books count;
- available books count.*/
-- Aggregation table creation (MySQL doesn't support materialized views, so we have to use a table):*/
CREATE TABLE books_statistics
(
total INTEGER UNSIGNED NOT NULL,
given INTEGER UNSIGNED NOT NULL,
rest INTEGER UNSIGNED NOT NULL
);

-- Aggregation table truncation:
TRUNCATE TABLE books_statistics;

-- Aggregation table data initialization:
INSERT INTO books_statistics
	(total, 
	given,
	rest)
SELECT IFNULL(total, 0),
	IFNULL(given, 0),
	IFNULL(total - given, 0) AS rest
FROM (SELECT (SELECT SUM(b_quantity)
			FROM books) AS total,
	(SELECT COUNT(sb_book)
	FROM subscriptions
	WHERE sb_is_active = 'Y') AS given)
AS prepared_data;

-- Old versions of triggers deletion (convenient for debug):
DROP TRIGGER upd_bks_sts_on_books_ins;
DROP TRIGGER upd_bks_sts_on_books_del;
DROP TRIGGER upd_bks_sts_on_books_upd;

-- We have to tell MySQL where the real query ends:
DELIMITER $$

-- Trigger for books insertion:
/*(In MySQL triggers are NOT activated by cascade operations, so you'll have
to create more triggers yourself to cover all situations of data modification.*/
CREATE TRIGGER upd_bks_sts_on_books_ins
BEFORE INSERT 
ON books
FOR EACH ROW 
BEGIN 
UPDATE books_statistics SET
total = total + NEW.b_quantity,
rest = total - given;
END;
$$

-- Trigger for books deletion:
CREATE TRIGGER upd_bks_sts_on_books_del
BEFORE DELETE
ON books
FOR EACH ROW
BEGIN
UPDATE books_statistics SET
	total = total - OLD.b_quantity,
	given = given - (SELECT COUNT(sb_book)
				FROM  subscriptions
				WHERE sb_book = OLD.b_id
				AND sb_is_active = 'Y'),
	rest = total - given;
END;
$$

-- Trigger for books quantity update:
CREATE TRIGGER upd_bks_sts_on_books_upd
BEFORE UPDATE
ON books
FOR EACH ROW
BEGIN
UPDATE books_statistics SET
	total = total - OLD.b_quantity + NEW.b_quantity,
	rest = total - given;
END;
$$

-- Now we have to restore normal query delimiter:
DELIMITER ;

-- Old versions of triggers deletion (convenient for debug) :
DROP TRIGGER upd_bks_sts_on_subscriptions_ins;
DROP TRIGGER upd_bks_sts_on_subscriptions_del;
DROP TRIGGER upd_bks_sts_on_subscriptions_upd;

-- We have to tell MySQL where the real query ends:
DELIMITER $$

-- Trigger for subscriptions insertion:
CREATE TRIGGER upd_bks_sts_on_subscriptions_ins
BEFORE INSERT
ON subscriptions
FOR EACH ROW
BEGIN

SET @delta = 0;
IF (NEW.sb_is_active = 'Y') THEN
SET @delta = 1;
END IF;

UPDATE books_statistics SET
rest = rest - @delta,
given = given + @delta;
END ;
$$

-- Trigger for subscriptions deletion:
CREATE TRIGGER upd_bks_sts_on_subscriptions_del
BEFORE DELETE
ON subscriptions
FOR EACH ROW
BEGIN

SET @delta = 0;

IF (OLD.sb_is_active = 'Y') THEN
SET @delta = 1;
END IF;

UPDATE books_statistics SET
	rest = rest + @delta,
	given = given - @delta;
END;
$$

-- Trigger for subscriptions modification:
CREATE TRIGGER upd_bks_sts_on_subscriptions_upd
BEFORE UPDATE
ON subscriptions
FOR EACH ROW
BEGIN
SET @delta = 0;
IF ((NEW.sb_is_active = 'Y') AND (OLD.sb_is_active = 'N')) THEN
SET @delta = 1;
END IF;

IF ((NEW.sb_is_active = 'N') AND (OLD.sb_is_active = 'Y')) THEN
SET @delta = 1;
END IF;

UPDATE books_statistics SET
rest = rest + @delta,
given = given - @delta;
END;
$$

-- Now we have to restore normal query delimiter:
DELIMITER ;

SELECT *
FROM books_statistics;

SELECT *
FROM subscriptions;

/* 4. Create a view to speed up the retrieval of “subscriptions” table
data in “human-readable form” (i.e. with books names,
subscribers names, etc.....)*/
-- Caching table creation:
CREATE TABLE subscriptions_ready
(
sb_id INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
sb_subscriber VARCHAR(150) NOT NULL,
sb_book VARCHAR(150) NOT NULL,
sb_start DATE NOT NULL,
sb_finish DATE NOT NULL,
sb_is_active ENUM ('Y', 'N') NOT NULL,
CONSTRAINT PK_subscriptions PRIMARY KEY (sb_id)
);
-- Caching table truncation:
TRUNCATE TABLE subscriptions_ready;

-- Caching table data initialization:
INSERT INTO subscriptions_ready
	(sb_id,
	sb_subscriber,
	sb_book,
	sb_start,
	sb_finish,
	sb_is_active)
SELECT sb_id,
	s_name AS sb_subscriber,
	b_name AS sb_book,
	sb_start,
	sb_finish,
	sb_is_active
FROM books
JOIN subscriptions ON b_id = sb_book
JOIN subscribers ON sb_subscriber = s_id;

-- Old versions of triggers deletion (convenient for debug):
DROP TRIGGER upd_sbs_rdy_on_books_del;
DROP TRIGGER upd_sbs_rdy_on_books_upd;

-- We have to tell MySQL where the real query ends:
DELIMITER $$

-- Trigger for books deletion:
CREATE TRIGGER upd_sbs_rdy_on_books_del
AFTER DELETE
ON books
FOR EACH ROW
BEGIN
DELETE FROM subscriptions_ready;
INSERT INTO subscriptions_ready
	(sb_id,
	sb_subscriber,
	sb_book,
	sb_start,
	sb_finish,
	sb_is_active)
SELECT sb_id,
	sb_subscriber,
	sb_book,
	sb_start,
	sb_finish,
	sb_is_active
FROM books
JOIN subscriptions ON b_id = sb_book
JOIN subscribers ON sb_subscriber = s_id;
END;
$$

-- Trigger for books modification:
CREATE TRIGGER upd_sbs_rdy_on_books_upd
AFTER UPDATE
ON books
FOR EACH ROW
BEGIN
IF (OLD.b_name != NEW.b_name)
THEN
DELETE FROM subscriptions_ready ;
INSERT INTO subscriptions_ready
	(sb_id,
	sb_subscriber,
	sb_book,
	sb_start,
	sb_finish,
	sb_is_active)
SELECT sb_id,
	sb_subscriber,
	sb_book,
	sb_start,
	sb_finish,
	sb_is_active
FROM books
JOIN subscriptions ON b_id = sb_book
JOIN subscribers ON sb_subscriber = s_id;
END IF;
END;
$$

-- Now we have to restore normal query delimiter:
DELIMITER ;

-- Old versions of triggers deletion (convenient for debug) :
DROP TRIGGER upd_sbs_rdy_on_subscribers_del;
DROP TRIGGER upd_sbs_rdy_on_subscribers_upd;

-- We have to tell MySQL where the real query ends:
DELIMITER $$

-- Trigger for subscribers deletion:
CREATE TRIGGER upd_sbs_rdy_on_subscribers_del
AFTER DELETE
ON subscribers
FOR EACH ROW
BEGIN
DELETE FROM subscriptions_ready ;
INSERT INTO subscriptions_ready
	(sb_id,
	sb_subscriber,
	sb_book,
	sb_start,
	sb_finish,
	sb_is_active)
SELECT sb_id,
	sb_subscriber,
	sb_book,
	sb_start,
	sb_finish,
	sb_is_active
FROM books
JOIN subscriptions ON b_id = sb_book
JOIN subscribers ON sb_subscriber = s_id;
END;
$$

-- Trigger for subscribers modification:
CREATE TRIGGER upd_sbs_rdy_on_subscribers_upd
AFTER UPDATE
ON subscribers
FOR EACH ROW
BEGIN
IF (OLD.s_name != NEW.s_name)
THEN
DELETE FROM subscriptions_ready ;
INSERT INTO subscriptions_ready
	(sb_id,
	sb_subscriber,
	sb_book,
	sb_start,
	sb_finish,
	sb_is_active)
SELECT sb_id,
	sb_subscriber,
	sb_book,
	sb_start,
	sb_finish,
	sb_is_active
FROM books
JOIN subscriptions ON b_id = sb_book
JOIN subscribers ON sb_subscriber = s_id;
END IF;
END;
$$

-- Now we have to restore normal query delimiter:
DELIMITER ;

-- Old versions of triggers deletion (convenient for debug) :
DROP TRIGGER upd_sbs_rdy_on_subscriptions_ins;
DROP TRIGGER upd_sbs_rdy_on_subscriptions_del;
DROP TRIGGER upd_sbs_rdy_on_subscriptions_upd;

-- We have to tell MySQL where the real query ends:
DELIMITER $$

-- Trigger for subscriptions modification:
CREATE TRIGGER upd_sbs_rdy_on_subscriptions_ins
AFTER UPDATE
ON subscriptions
FOR EACH ROW
BEGIN
INSERT INTO subscriptions_ready
	(sb_id,
	sb_subscriber,
	sb_book,
	sb_start,
	sb_finish,
	sb_is_active)
SELECT sb_id,
	sb_subscriber,
	sb_book,
	sb_start,
	sb_finish,
	sb_is_active
FROM books
JOIN subscriptions ON b_id = sb_book
JOIN subscribers ON sb_subscriber = s_id
WHERE s_id = NEW.sb_subscriber
AND d_id = NEW.sb_book;
END;
$$

-- Trigger for subscriptions deletion:
CREATE TRIGGER upd_sbs_rdy_on_subscriptions_del
AFTER DELETE
ON subscriptions
FOR EACH ROW
BEGIN
DELETE FROM subscriptions_ready
WHERE subscriptions_ready.sb_id = OLD.sb_id;
END;
$$

-- Trigger for subscriptions modification:
CREATE TRIGGER upd_sbs_rdy_on_subscriptions_upd
AFTER UPDATE
ON subscriptions
FOR EACH ROW
BEGIN
UPDATE subscriptions_ready
		JOIN (SELECT sb_id, s_name, b_name
		FROM books
		JOIN subscriptions ON b_id = sb_book
		JOIN subscribers ON sb_subscriber = s_id
		WHERE s_id = NEW.sb_subscriber
		AND b_id = NEW.sb_book
		AND sb_id = NEW.sb_id) AS new_data
SET subscriptions_ready.sb_id = NEW.sb_id,
subscriptions_ready.sb_subscriber = new_data.s_name,
subscriptions_ready.sb_book = new_data.b_name,
subscriptions_ready.sb_start = NEW.sb_start,
subscriptions_ready.sb_finish = NEW.sb_finish,
subscriptions_ready.sb_is_active = NEW.sb_is_active
WHERE subscriptions_ready.sb_id = OLD.sb_id;
END ;
$$

SELECT *
FROM subscriptions_ready;

/* 03 - Using Views to Obscure Database Structures and Data Values */
/* 5. Create a view on "subscriptions" table to hide the information about subscribers. */
CREATE VIEW subscriptions_anonymous
AS
	SELECT sb_id,
		sb_book,
		sb_start,
		sb_finish,
		sb_is_active
    FROM subscriptions;

SELECT *
FROM subscriptions_anonymous;

/* 6. Create a view on "subscriptions" table to present all dates in Unixtime format. */
-- without time zone conversion
CREATE VIEW subscriptions_unixtime
AS
	SELECT sb_id,
		sb_subscriber,
		sb_book,
		UNIX_TIMESTAMP(sb_start) AS sb_start,
		UNIX_TIMESTAMP(sb_finish) AS sb_finish,
		sb_is_active
    FROM subscriptions;

SELECT *
FROM subscriptions_unixtime;

-- with time zone conversion
CREATE VIEW subscriptions_unixtime_tz
AS
	SELECT sb_id,
		sb_subscriber,
		sb_book,
		UNIX_TIMESTAMP(CONVERT_TZ(sb_start, '+00:00', '+03:00')) AS sb_start,
		UNIX_TIMESTAMP(CONVERT_TZ(sb_finish, '+00:00', '+03:00')) AS sb_finish,
		sb_is_active
    FROM subscriptions;

SELECT *
FROM subscriptions_unixtime_tz;

/* 7. Create a view on "subscriptions" table to present all dates in "YYYY-MM-DD DW" format, where "DW" is a full day of week name (e.g., "Sunday", "Monday", etc.)*/
CREATE VIEW subscriptions_data_dw
AS
	SELECT sb_id,
		sb_subscriber,
		sb_book,
        CONCAT(sb_start, ' - ', DAYNAME(sb_start)) AS sb_start_dw,
        CONCAT(sb_finish, ' - ', DAYNAME(sb_finish)) AS sb_finish_dw,
		sb_is_active
    FROM subscriptions;

SELECT *
FROM subscriptions_data_dw;

/* 04 - Using Updatable Views to Modify Data */
/* 8. Create a view on “subscribers” table to present all subscribers’
names in upper case while allowing to modify “subscribers”
table via operations with the view.*/
-- This view allows deletion only:
CREATE VIEW subscribers_upper_case
AS
	SELECT s_id, UPPER(s_name) AS s_name
	FROM subscribers

-- This view allows both deletion and modification:
CREATE VIEW subscribers_upper_case_trick
AS
SELECT s_id, s_name, UPPER(s_name) AS s_name_upper /* s_name is for modification, mySQL doesn't allow insertion via views with multiple refereces to the same field*/
FROM subscribers

SELECT *
FROM subscribers_upper_case;

/* 9. Create a view on “subscriptions” table to present subscription
start and finish dates as a single string while allowing to modify
“subscriptions” table via operations with the view.*/
-- This view allows deletion only:
CREATE VIEW subscriptions_wcd
AS
	SELECT sb_id,
			sb_subscriber,
            sb_book,
            CONCAT(sb_start, ' - ', sb_finish) AS sb_dates,
            sb_is_active
	FROM subscriptions
SELECT *
FROM subscriptions_wcd
-- This view allows both deletion and modification: (mySQL doesn't allow insertion via views with multiple refereces to the same field)
CREATE VIEW subscriptions_wcd_trick
AS
	SELECT sb_id,
			sb_subscriber,
            sb_book,
            CONCAT(sb_start, ' - ', sb_finish) AS sb_dates,
            sb_start,
            sb_finish,
            sb_is_active
	FROM subscriptions;
    
SELECT *
FROM subscriptions_wcd_trick;

/* 05 - Using Triggers on Views to Modify Data*/
/* ! MySQL does not support triggers on views*/
/* 10. Create a view on “subscribers” table to present all the data in
“human-readable” form (i.e. with explicit names/titles instead
of ids) while allowing to modify “subscribers” table via
operations with the view.*/
CREATE VIEW subscriptions_with_text
AS
	SELECT sb_id,
		s_name AS sb_subscriber,
		b_name AS sb_book,
        sb_start,
        sb_finish,
        sb_is_active
	FROM subscriptions
	JOIN subscribers ON sb_subscriber = s_id
	JOIN books ON sb_book = b_id;
SELECT *
FROM subscriptions_with_text;

/* 11. Create a view to select books’ titles along with books’ genres
while allowing to add new genres via operations with the view.*/
CREATE VIEW books_with_genres
AS
SELECT b_id, b_name,
	GROUP_CONCAT(g_name) AS genres
FROM books
JOIN m2m_books_genres USING(b_id)
JOIN genres USING(g_id)
GROUP BY b_id;

SELECT *
FROM books_with_genres;