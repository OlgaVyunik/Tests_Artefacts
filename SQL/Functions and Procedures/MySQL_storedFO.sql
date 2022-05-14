/* 01 - Using Stored Functions for Data Operations*/
/* 1. Create a stored function that receives a subscription start and
end dates and returns the difference (in days) along with
suffixes:
[OK], if the difference is less than 10 days;
[NOTICE], if the difference is between 10 and 30 days;
[WARNING], if the difference is more than 30 days.*/
DELIMITER $$
CREATE FUNCTION READ_DURATION_AND_STATUS(start_date DATE, finish_date DATE)
RETURNS VARCHAR(150) DETERMINISTIC
BEGIN
DECLARE days INT;
DECLARE message VARCHAR (150) ;
SET days = DATEDIFF(finish_date, start_date) ;
CASE
WHEN (days<10) THEN SET message = ' OK';
WHEN ((days>=10) AND (days<=30)) THEN SET message = ' NOTICE';
WHEN (days>30) THEN SET message = ' WARNING' ;
END CASE;
RETURN CONCAT (days, message) ;
END$$
DELIMITER ;

SELECT sb_id, sb_start, sb_finish,
READ_DURATION_AND_STATUS(sb_start, sb_finish) AS rdns
FROM subscriptions
WHERE sb_is_active = 'Y';

/* 2. Create a stored function that returns “empty values” of a
primary key of a table. E.g.: for 1, 3, 8 primary key values
“empty values” are: 2, 4, 5, 6, 7.*/
-- MySQL has the following limitations:
-- dynamic SQL is not allowed in stored functions (so, we may process only one pre-defined table);
-- stored function can not return tables (so, we may return a string only).
DROP FUNCTION IF EXISTS GET_FREE_KEYS_IN_SUBSCRIPTIONS;
DELIMITER $$
CREATE FUNCTION GET_FREE_KEYS_IN_SUBSCRIPTIONS() RETURNS VARCHAR (21845) /* max srtring lenth in MySQL*/
DETERMINISTIC
BEGIN
	DECLARE start_value INT DEFAULT 0;
	DECLARE stop_value INT DEFAULT 0;
	DECLARE done INT DEFAULT 0;
	DECLARE free_keys_string VARCHAR(21845) DEFAULT '';
	DECLARE free_keys_cursor CURSOR FOR
SELECT `start`,  `stop`
FROM (SELECT min_t.sb_id > + 1 AS `start`,
	(SELECT MIN(sb_id) - 1
	FROM subscriptions AS `x`
	WHERE `x`.sb_id > min_t.sb_id) AS `stop`
FROM subscriptions AS min_t
UNION
SELECT 1 AS `start`,
		(SELECT MIN(sb_id) - 1
		FROM subscriptions AS `x`
        WHERE sb_id > 0) AS `stop`
) AS `data`
WHERE `stop` >= `start`
ORDER BY `start`, `stop`;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

OPEN free_keys_cursor;
BEGIN
read_loop: LOOP
	FETCH free_keys_cursor INTO start_value, stop_value;
	IF done THEN
	LEAVE read_loop;
	END IF;
for_loop: LOOP
	SET free_keys_string = CONCAT(free_keys_string, start_value, ',');
	SET start_value := start_value + 1;
	IF start_value <= stop_value THEN
	ITERATE for_loop;
	END IF;
LEAVE for_loop;
END LOOP for_loop;
END LOOP read_loop;
END; 
CLOSE free_keys_cursor;
RETURN SUBSTRING(free_keys_string, 1, CHAR_LENGTH(free_keys_string) - 1); /* чтобы убрать , в конце строки*/
END ;
$$
DELIMITER ;

SELECT GET_FREE_KEYS_IN_SUBSCRIPTIONS();

/* 3. Create a stored function that updates “books_statistics” table
(see. “Using Caching Views and Tables to Select Data” topic)
and returns a delta of registered books count. */
-- SELECT * FROM books_statistics;
DROP FUNCTION IF EXISTS BOOKS_DELTA;
DELIMITER $$
CREATE FUNCTION BOOKS_DELTA() RETURNS INT
BEGIN
DECLARE old_books_count INT DEFAULT 0;
DECLARE new_books_count INT DEFAULT 0;
SET old_books_count := (SELECT total FROM books_statistics) ;
UPDATE books_statistics
JOIN
(SELECT IFNULL(total, 0) AS total,
IFNULL(given, 0) AS given,
IFNULL(total - given, 0) AS rest
FROM (SELECT (SELECT SUM(b_quantity)
				FROM books) AS total,
				(SELECT COUNT (sb_book)
				FROM subscriptions
				WHERE sb_is_active = 'Y') AS given)
AS prepared_data) AS src
SET books_statistics.total = src.total,
books_statistics.given = src.given,
books_statistics.rest = src.rest;
SET new_books_count := (SELECT total FROM books_statistics) ;
RETURN (new_books_count - old_books_count) ;
END ;
$$
DELIMITER ;

SELECT BOOKS_DELTA()

/* 02 - Using Stored Functions for Data Control */
/* 4. Create a stored function that checks all three conditions from
“Using Triggers to Control Data Modification” topic’s Task 1 and
returns a negative number, modulo value of which is equal to
the number of a violated rule.*/
DELIMITER $$
CREATE FUNCTION CHECK_SUBSCRIPTION_DATES (sb_start DATE,
										sb_finish DATE,
										is_insert INT)
RETURNS INT
DETERMINISTIC
BEGIN
DECLARE result INT DEFAULT 1;

-- If the subscription start date is in the future:
IF (sb_start > CURDATE())
THEN
SET result = -1;
END IF;

-- If the subscription end date is in the past:
IF ((sb_finish < CURDATE()) AND (is_insert = 1))
THEN
SET result = -2;
END IF;

-- If the subscription start date is less than the end date:
IF (sb_finish < sb_start)
THEN
SET result = -3;
END IF;

RETURN result;
END ;
$$
DELIMITER ;

SELECT CHECK_SUBSCRIPTION_DATES(sb_start, sb_finish, 1)
FROM subscriptions;

/* 5. Create a stored function that checks the condition from “Using
Triggers to Control Data Format and Values” topic’s Task 1 and
returns 1 if the condition is met, and O otherwise.

Create a trigger to only allow registration of subscribers with a
dot and at least two words in their names.
[Return 1] if the condition is met.
[Return 0] if the condition is violated */
DROP FUNCTION IF EXISTS CHECK_SUBSCRIBER_NAME;
DELIMITER $$
CREATE FUNCTION CHECK_SUBSCRIBER_NAME (subscriber_name VARCHAR (150)) RETURNS INT
DETERMINISTIC
BEGIN
IF ((CAST(subscriber_name AS CHAR CHARACTER SET cp1251) REGEXP
CAST('^[a-zA-Zа-яА-ЯёЁ\'-]+([^a-zA-Zа-яА-ЯёЁ\'-]+[a-zA-Zа-яА-ЯёЁ\'.-]+){1,}$' AS CHAR CHARACTER SET cp1251)) = 0)
OR (LOCATE('.', subscriber_name) = 0)
THEN
RETURN 0;
ELSE
RETURN 1;
END IF; 
END;
$$
DELIMITER ;
/*We use the same approach as in “Using Triggers to Control Data Format and Values”
topic’s Task 1, but here we do not block the operation, but only return the value.*/

SELECT s_name, CHECK_SUBSCRIBER_NAME(s_name)
FROM subscribers;

/* 03 - Using Stored Procedures to Execute Dynamic Queries */
/* 6. Create a stored procedure that “compresses” all “empty values”
of a primary key of a table and returns the number of modified
values. E.g.: for 1, 3, 8 primary key values the new sequence
should be: 1, 2, 3, and the returned value should be 1.*/
DROP PROCEDURE COMPACT_KEYS;
DELIMITER $$
CREATE PROCEDURE COMPACT_KEYS (IN table_name VARCHAR(150) ,
								IN pk_name VARCHAR(150) ,
								OUT keys_changed INT)
BEGIN
SET keys_changed = 0;
SELECT                             /*This is for debug only*/
CONCAT('Point 1. table_name = ', table_name, ', pk_name = ',
pk_name, ', keys_changed = ', IFNULL(keys_changed, 'NULL')) ;
/* Here we prepare the query to fetch all "empty keys" values */
SET @empty_key_query =
CONCAT('SELECT MIN(empty_key) AS empty_key INTO @empty_key_value
FROM (SELECT `left`.', pk_name, ' + 1 AS empty_key
FROM ', table_name, ' AS `left`
LEFT OUTER JOIN ', table_name, ' AS `right`
ON `left`.', pk_name,
' +1 = `right`.', pk_name, '
WHERE `right`.', pk_name, ' IS NULL
UNION
SELECT 1 AS empty_key
FROM ', table_name, '
WHERE NOT EXISTS(SELECT ', pk_name, '
FROM ', table_name, '
WHERE ', pk_name, ' = 1)) AS prepared_data
WHERE empty_key < (SELECT MAX(', pk_name, ')
FROM ', table_name, ')');
/*This is for debug only*/
SET @max_key_query =
CONCAT('SELECT MAX(', pk_name, ')
INTO @max_key_value FROM ', table_name, '');
SELECT CONCAT('Point 2. empty_key_query = ', @empty_key_query,
'max_key_query = ', @max_key_query);

PREPARE empty_key_stmt FROM @empty_key_query;
PREPARE max_key_stmt FROM @max_key_query;
-- Now we get all "empty keys" values, loop through this set...
while_loop: LOOP
EXECUTE empty_key_stmt;
SELECT CONCAT('Point 3. @empty_key value = ', @empty_key_value) ; /* This is for debug only*/
IF (@empty_key_value IS NULL)
THEN LEAVE while_loop;
END IF;
EXECUTE max_key_stmt;
SET @update_key_query =
CONCAT('UPDATE ', table_name, ' SET ', pk_name,
' = @empty_key_value WHERE ', pk_name, ' = ', @max_key_value) ;
-- ... and modify corresponding values
SELECT CONCAT('Point 4. @update_key_query = ', @update_key_query) ;
PREPARE update_key_stmt FROM @update_key_query;
EXECUTE update_key_stmt;
DEALLOCATE PREPARE update_key_stmt;

SET keys_changed = keys_changed + 1;
ITERATE while_loop;
END LOOP while_loop;

DEALLOCATE PREPARE max_key_stmt;
DEALLOCATE PREPARE empty_key_stmt;
END;
$$
DELIMITER ;

CALL COMPACT_KEYS ('subscriptions_ready', 'sb_id', @keys_changed);
SELECT @keys_changed;

CALL COMPACT_KEYS ('books', 'b_id', @keys_changed);
SELECT @keys_changed;

SELECT *
FROM subscriptions_ready;
SELECT *
FROM books;

/* 7. Create a stored procedure that makes a list of all views, triggers
and foreign keys for a given table.*/
DELIMITER $$
CREATE PROCEDURE SHOW_TABLE_OBJECTS (IN table_name VARCHAR(150) )
BEGIN
SET @query_text = '
SELECT \'foreign_key\' AS object_type,
constraint_name AS object_name
FROM information_schema.table_constraints
WHERE table_schema = DATABASE ()
AND table_name = \'_FP_TABLE_NAME_PLACEHOLDER_\'
AND constraint_type = \'FOREIGN KEY\'
UNION
SELECT \'trigger\' AS object_type,
trigger_name AS object_name
FROM information_schema.triggers
WHERE event_object_schema = DATABASE ()
AND event_object_table = \'_FP_TABLE_NAME_PLACEHOLDER_\'
UNION
SELECT \'view\' AS object_type,
table_name AS object_name
FROM information_schema.views
WHERE table_schema = DATABASE ()
AND view_definition LIKE \'%*_FP_TABLE_NAME_PLACEHOLDER_%\'';
SET @query_text = REPLACE (@query_text,
'_FP_TABLE_NAME_PLACEHOLDER_', table_name) ;
PREPARE query_stmt FROM @query_text;
EXECUTE query_stmt;
DEALLOCATE PREPARE query_stmt;
END;
$$
DELIMITER ;

CALL SHOW_TABLE_OBJECTS('subscriptions');

/* 04 - Using Stored Procedures for Performance Optimization */
/* 8. Create a stored procedure that is scheduled to update
“books_statistics” table (see “Using Caching Views and Tables
to Select Data” topic’s Task 1) every hour. */
DROP PROCEDURE UPDATE_BOOKS_STATISTICS
DELIMITER $$
CREATE PROCEDURE UPDATE_BOOKS_STATISTICS()
BEGIN
-- Let’s check if the table exists.
IF (NOT EXISTS(SELECT *
FROM `information_schema`.`tables`
WHERE `table_schema` = DATABASE() 
AND `table_name` = 'books_statistics'))
THEN
SIGNAL SQLSTATE '45001'
SET MESSAGE_TEXT = 'The books_statistics table is missing.',
MYSQL_ERRNO = 1001;
END IF;
-- Here we update the table.
UPDATE books_statistics
JOIN
(SELECT IFNULL(total, 0) AS total,
IFNULL(given, 0) AS given,
IFNULL(total - given, 0) AS rest
FROM (SELECT (SELECT SUM(b_quantity) 
FROM books) AS total,
(SELECT COUNT(sb_book)
FROM subscriptions
WHERE sb_is_active = 'Y') AS given)
AS prepared_data
) AS src
SET
books_statistics.total = src.total,
books_statistics.given = src.given,
books_statistics.rest = src.rest;
END;
$$
DELIMITER ;

CALL UPDATE_BOOKS_STATISTICS;

-- Scheduler activation.
SET GLOBAL event_scheduler = ON;
-- Procedure call scheduling.
CREATE EVENT update_books_statistics_hourly
ON SCHEDULE 
EVERY 1 HOUR
STARTS DATE (NOW()) + INTERVAL (HOUR(NOW())+1) HOUR + INTERVAL 1 MINUTE
ON COMPLETION PRESERVE
DO
CALL UPDATE_BOOKS_STATISTICS;

SELECT * FROM `information_schema`.`events`;

/* 9. Create a stored procedure that is scheduled to optimize
(compress) all database tables once per day.*/
DELIMITER $$
CREATE PROCEDURE OPTIMIZE_ALL_TABLES()
BEGIN
DECLARE done INT DEFAULT 0;
DECLARE tbl_name VARCHAR(200) DEFAULT '' ;
DECLARE all_tables_cursor CURSOR FOR 
-- Here we retrieve the list of all tables.
SELECT `table_name`
FROM `information_schema`.`tables`
WHERE table_schema = DATABASE()
AND table_type = 'BASE TABLE' ;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
OPEN all_tables_cursor;
tables_loop: LOOP
FETCH all_tables_cursor INTO tbl_name;
IF done THEN
LEAVE tables_loop;
END IF;     
-- Here we optimize each table.
SET @table_opt_query = CONCAT('OPTIMIZE TABLE `', tbl_name, '`');
PREPARE table_opt_stmt FROM @table_opt_query;
EXECUTE table_opt_stmt;
DEALLOCATE PREPARE table_opt_stmt;
END LOOP tables_loop;
CLOSE all_tables_cursor;
END;
$$
DELIMITER ;

CALL OPTIMIZE_ALL_TABLES;

-- Scheduler activation.
SET GLOBAL event_scheduler = ON;
-- Procedure call scheduling.
CREATE EVENT optimize_all_tables_daily
ON SCHEDULE
EVERY 1 DAY
STARTS DATE(NOW()) + INTERVAL 1 HOUR
ON COMPLETION PRESERVE
DO
CALL OPTIMIZE_ALL_TABLES;

SELECT * FROM `information_schema`.`events`;

/* 05 - Using Stored Procedures to Manipulate Database Objects */
/* 10. Create a stored procedure that automatically creates and
populates with data “books_statistics” table (see “Using
Caching Views and Tables to Select Data” topic’s Task 1).*/
DELIMITER $$
CREATE PROCEDURE CREATE_BOOKS_STATISTICS()
BEGIN
-- Check, if table exists.
IF NOT EXISTS
(SELECT `table_name`
FROM `information_schema`.`tables`
WHERE table_schema = DATABASE()
AND table_type = 'BASE TABLE'
AND `table_name` = 'books_statistics')
THEN
-- Create table, if not exists.
CREATE TABLE books_statistics
(
total INTEGER UNSIGNED NOT NULL,
given INTEGER UNSIGNED NOT NULL,
rest INTEGER UNSIGNED NOT NULL
);
-- Populate table with data.
INSERT INTO books_statistics
(total,
given,
rest)
SELECT IFNULL(total, 0),
IFNULL(given, 0),
IFNULL(total - given, 0) AS rest
FROM (SELECT (SELECT SUM(b_quantity)
FROM books ) AS total,
(SELECT COUNT (sb_book)
FROM subscriptions
WHERE sb_is_active = 'Y') AS given)
AS prepared_data;
-- Just update table, if exists.
ELSE
UPDATE books_statistics
JOIN
(SELECT IFNULL(total, 0) AS total,
IFNULL(given, 0) AS given,
IFNULL(total - given, 0) AS rest
FROM (SELECT (SELECT SUM(b_quantity)
FROM books) AS total,
(SELECT COUNT(sb_book)
FROM subscriptions
WHERE sb_is_active = 'Y') AS given)
AS prepared_data) AS src
SET books_statistics.total = src.total,
books_statistics.given = src.given,
books_statistics.rest = src.rest;
END IF;
END;
$$
DELIMITER ;

DROP TABLE books_statistics;
CALL CREATE_BOOKS_STATISTICS;
SELECT * FROM books_statistics;

/* 11. Create a stored procedure that automatically creates and
populates with data “tables_rc” table that contains all database
tables names along with records count for each table.*/
DELIMITER $$
CREATE PROCEDURE CACHE_TABLES_RC()
BEGIN
DECLARE done INT DEFAULT 0;
DECLARE tbl_name VARCHAR(200) DEFAULT '';
DECLARE all_tables_cursor CURSOR FOR
SELECT `table_name`
FROM information_schema.`tables`
WHERE table_schema = DATABASE()
AND table_type = 'BASE TABLE';
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
-- Check, if table exists.
IF NOT EXISTS
(SELECT `table_name` 
FROM information_schema.`tables`
WHERE table_schema = DATABASE()
AND table_type = 'BASE TABLE'
AND `table_name` = 'tables_rc')
THEN
-- Create table, if not exists.
CREATE TABLE tables_rc
(
`table_name` VARCHAR (200) ,
rows_count INT
);
END IF;
/* Clear table. WARNING! In real production
environment some applications may crash if they
don’t expect this table to be empty.*/
TRUNCATE TABLE tables_rc;
OPEN all_tables_cursor; 
tables_loop: LOOP
FETCH all_tables_cursor INTO tbl_name;
IF done THEN
LEAVE tables_loop;
END IF;
SET @table_rc_query = CONCAT('SELECT COUNT(1) INTO @tbl_rc FROM ', tbl_name, '');
PREPARE table_opt_stmt FROM @table_rc_query;
EXECUTE table_opt_stmt;
DEALLOCATE PREPARE table_opt_stmt;
-- Populate table with data.
INSERT INTO tables_rc (`table_name`, rows_count)
VALUES (tbl_name, @tbl_rc) ;
END LOOP tables_loop;
CLOSE all_tables_cursor;
END;
$$
DELIMITER ;

CALL CACHE_TABLES_RC;
SELECT * FROM tables_rc;




    



 