/* 1. Create a stored function that receives a subscription start and
end dates and returns the difference (in days) along with
suffixes:
[OK], if the difference is less than 10 days;
[NOTICE], if the difference is between 10 and 30 days;
[WARNING], if the difference is more than 30 days.*/
CREATE FUNCTION READ_DURATION_AND_STATUS (start_date IN DATE, finish_date IN DATE)
RETURN NVARCHAR2
DETERMINISTIC
IS
days NUMBER(10);
message NVARCHAR2(150);
BEGIN
SELECT (finish_date - start_date) INTO days FROM dual;
SELECT 
	CASE
		WHEN (days<10) THEN ' OK'
		WHEN ((days>=10) AND (days<=30)) THEN ' NOTICE!'
		WHEN (days>30) THEN ' WARNING'
	END 
    INTO message FROM dual;
RETURN CONCAT(days, message) ;
END ;

SELECT "sb_id", "sb_start", "sb_finish",
READ_DURATION_AND_STATUS("sb_start", "sb_finish") AS "rdns"
FROM "subscriptions"
WHERE "sb_is_active" = 'Y';

/* 2. Create a stored function that returns “empty values” of a
primary key of a table. E.g.: for 1, 3, 8 primary key values
“empty values” are: 2, 4, 5, 6, 7.*/
-- Drop old type definition:
DROP TYPE "t_tf_free_keys_table";
/
DROP TYPE "t_tf_free_keys_row";
/
-- Create data type definition (for a single row):
CREATE TYPE "t_tf_free_keys_row" AS OBJECT (
"start" NUMBER,
"stop" NUMBER
);
/
-- Create data type definition (for a table):
CREATE TYPE "t_tf_free_keys_table" IS TABLE OF "t_tf_free_keys_row";
/
-- Create the function itself:
DROP FUNCTION GET_FREE_KEYS;
CREATE OR REPLACE FUNCTION GET_FREE_KEYS(table_name IN VARCHAR2,
                                            pk_name IN VARCHAR2)
RETURN "t_tf_free_keys_table"
AS
result_tab "t_tf_free_keys_table" := "t_tf_free_keys_table"();
TYPE type_free_keys_cursor IS REF CURSOR;
free_keys_cursor type_free_keys_cursor;
start_value NUMBER;
stop_value NUMBER;
final_query VARCHAR2 (1024) ;
BEGIN
final_query := 'SELECT "start", "stop"
                FROM (SELECT "min_t"."' || pk_name || '" + 1 AS "start",
                (SELECT MIN("' || pk_name || '") - 1
                FROM "' || table_name || '" "x"
                WHERE "x"."' || pk_name || '" > "min_t"."' || pk_name || '") AS "stop"
        FROM "' || table_name || '" "min_t"
        UNION
        SELECT 1 AS "start",
                    (SELECT MIN("' || pk_name || '") - 1
                    FROM "' || table_name || '" "x"
                    WHERE "' || pk_name || '" > 0) AS "stop"
        FROM dual
        ) "data"
WHERE "stop" >= "start"
ORDER BY "start", "stop"' ;

OPEN free_keys_cursor FOR final_query;
LOOP
FETCH free_keys_cursor INTO start_value, stop_value;
EXIT WHEN free_keys_cursor%NOTFOUND;
result_tab.extend;
result_tab(result_tab.last) := "t_tf_free_keys_row" (start_value, stop_value) ;
END LOOP;

CLOSE free_keys_cursor;
RETURN result_tab;
END;
/

SELECT * FROM TABLE(GET_FREE_KEYS('subscriptions', 'sb_id'))

/* 3. Create a stored function that updates “books_statistics” table
(see. “Using Caching Views and Tables to Select Data” topic)
and returns a delta of registered books count. */
-- We have to drop the materialized view before the table (with the same name) creation:
DROP MATERIALIZED VIEW "books_statistics";
-- Aggregation table truncation:
CREATE TABLE "books_statistics"
(
"total" NUMBER (10) ,
"given" NUMBER (10) ,
"rest" NUMBER(10)
);

-- Aggregation table data initialization:
INSERT INTO "books_statistics"
            ("total",
            "given",
            "rest")
SELECT "total",
        "given",
        ("total" - "given") AS "rest"
FROM (SELECT SUM("b_quantity") AS "total"
        FROM "books")
JOIN (SELECT COUNT("sb_book") AS "given"
        FROM "subscriptions"
        WHERE "sb_is_active" = 'Y')
ON 1 =1;

CREATE OR REPLACE FUNCTION BOOKS_DELTA RETURN NUMBER IS
PRAGMA AUTONOMOUS_TRANSACTION ;
old_books_count NUMBER;
new_books_count NUMBER;
BEGIN
SELECT "total" INTO old_books_count FROM "books_statistics";
COMMIT ;
UPDATE "books_statistics"
SET ("total", "given", "rest") =
    (SELECT "total",
            "given",
            ("total" - "given") AS "rest"
    FROM (SELECT SUM("b_quantity") AS "total"
            FROM "books")
    JOIN (SELECT COUNT("sb_book") AS "given"
            FROM "subscriptions"
WHERE "sb_is_active" = 'Y')
ON 1 = 1);
COMMIT ;
SELECT "total" INTO new_books_count FROM "books_statistics";
COMMIT ;
RETURN (new_books_count - old_books_count) ;
END ;

SELECT * FROM "books_statistics"

SELECT BOOKS_DELTA FROM dual

/* 02 - Using Stored Functions for Data Control */
/* 4. Create a stored function that checks all three conditions from
“Using Triggers to Control Data Modification” topic’s Task 1 and
returns a negative number, modulo value of which is equal to
the number of a violated rule.*/
CREATE OR REPLACE FUNCTION CHECK_SUBSCRIPTION_DATES (sb_start DATE,
                                                    sb_finish DATE,
                                                    is_insert INT)
RETURN NUMBER DETERMINISTIC IS
result_value NUMBER := 1;
BEGIN
-- If the subscription start date is in the future:
IF (sb_start > TRUNC (SYSDATE) )
THEN
result_value := -1;
END IF;
-- If the subscription end date is in the past:
IF ((sb_finish < TRUNC(SYSDATE)) AND (is_insert = 1))
THEN
result_value := -2;
END IF;
-- If the subscription start date is less than the end date:
IF (sb_finish < sb_start)
THEN
result_value := -3;
END IF;

RETURN result_value;
END;

SELECT CHECK_SUBSCRIPTION_DATES("sb_start", "sb_finish", 1)
FROM "subscriptions";

/* 5. Create a stored function that checks the condition from “Using
Triggers to Control Data Format and Values” topic’s Task 1 and
returns 1 if the condition is met, and O otherwise.

Create a trigger to only allow registration of subscribers with a
dot and at least two words in their names.
[Return 1] if the condition is met.
[Return 0] if the condition is violated */
CREATE OR REPLACE
FUNCTION CHECK_SUBSCRIBER_NAME (subscriber_name NVARCHAR2)
RETURN NUMBER DETERMINISTIC IS
BEGIN
IF ((NOT REGEXP_LIKE(subscriber_name, '^[a-zA-Zà-ÿÀ-ß¸¨''-]+([^[a-zA-Zà-ÿÀ-ß¸¨''-]+[a-zA-Zà-ÿÀ-ß¸¨''.-]+){1,}$'))
OR (INSTRC(subscriber_name, '.', 1, 1) = 0))
THEN 
RETURN 0;
ELSE
RETURN 1;
END IF;
END;

SELECT "s_name", CHECK_SUBSCRIBER_NAME("s_name")
FROM "subscribers";

/* 03 - Using Stored Procedures to Execute Dynamic Queries */
/* 6. Create a stored procedure that “compresses” all “empty values”
of a primary key of a table and returns the number of modified
values. E.g.: for 1, 3, 8 primary key values the new sequence
should be: 1, 2, 3, and the returned value should be 1.*/
DROP PROCEDURE COMPACT_KEYS

CREATE PROCEDURE COMPACT_KEYS (table_name IN VARCHAR, pk_name IN VARCHAR,
keys_changed OUT NUMBER) AS
empty_key_query VARCHAR(1000) := '';
max_key_query VARCHAR(1000) := '';
empty_key_value NUMBER := NULL;
max_key_value NUMBER := NULL;
update_key_query VARCHAR(1000) := '';
BEGIN
keys_changed := 0;

--This is for debug only.
DBMS_OUTPUT.PUT_LINE('Point 1. table_name = ' || table_name ||
' || pk_name = ' || pk_name || ', keys_changed = ' || keys_changed); 

-- Here we prepare the query to fetch all “empty keys” values.
empty_key_query :=
'SELECT MIN("empty_key") AS "empty_key"
FROM (SELECT "left"."' || pk_name || '" + 1 AS "empty_key"
FROM "' || table_name || '"  "left"
LEFT OUTER JOIN "' || table_name || '" "right"
ON "left"."' || pk_name ||
'" + 1 = "right"."' || pk_name || '"
WHERE "right"."' || pk_name || '" IS NULL
UNION
SELECT 1 AS "empty_key"
FROM "' || table_name || '"
WHERE NOT EXISTS(SELECT "' || pk_name || '"
FROM = "' || table_name || '"
WHERE "' || pk_name ||
'" = 1)) "prepared_data"
WHERE "empty_key" < (SELECT MAX("' || pk_name || '")
FROM "' || table_name || '")';

max_key_query :=
'SELECT MAX("' || pk_name || '") FROM "' || table_name || '"';

-- This is for debug only.
DBMS_OUTPUT.PUT_LINE('Point 2. empty_key_query = ' || empty_key_query ||
CHR(13) || CHR(10) || ' max_key_query = ' || max_key_query) ;

LOOP
EXECUTE IMMEDIATE empty_key_query INTO empty_key_value; 
EXIT WHEN empty_key_value IS NULL;
-- Now we get all empty keys values, loop through this set...
EXECUTE IMMEDIATE max_key_query INTO max_key_value; 
-- .. and modify corresponding values.
update_key_query := 
'UPDATE "' || table_name || '" SET "' || pk_name ||
'" = ' || TO_CHAR(empty_key_value) || ' WHERE "' || pk_name ||
'" = ' || TO_CHAR(max_key_value) ;
-- This is for debug only.
DBMS_OUTPUT.PUT_LINE('Point 3. update_key_query = ' || update_key_query) ;
EXECUTE IMMEDIATE update_key_query; 
keys_changed := keys_changed + 1; 
END LOOP; 
END;
/

DECLARE
keys_changed_in_table NUMBER;
BEGIN
COMPACT_KEYS('books', 'b_id', keys_changed_in_table) ;
DBMS_OUTPUT.PUT_LINE('Keys changed: ' || keys_changed_in_table) ;
END;
COMPACT_KEYS('subscriptions', 'sb_id', keys_changed_in_table) ;
DBMS_OUTPUT.PUT_LINE('Keys changed: ' || keys_changed_in_table) ;
END;

SELECT *
FROM "subscriptions";
SELECT *
FROM "books";

/* 7. Create a stored procedure that makes a list of all views, triggers
and foreign keys for a given table.*/
CREATE OR REPLACE TYPE "all_views_row" AS OBJECT
(
"VIEW_NAME" VARCHAR2 (500) ,
"TEXT" VARCHAR2 (32767)
);
/
CREATE TYPE "all_views_table" IS TABLE OF "all_views_row";
/
CREATE OR REPLACE FUNCTION ALL_VIEWS_VARCHAR2
RETURN "all_views_table"
AS
result_table "all_views_table" := "all_views_table"() ;
CURSOR all_views_table_cursor IS
SELECT VIEW_NAME, TEXT
FROM ALL_VIEWS
WHERE OWNER = USER;
BEGIN
FOR one_row IN all_views_table_cursor
LOOP
result_table.extend;
result_table(result_table.last) :=
"all_views_row" (one_row."VIEW_NAME", one_row."TEXT") ;
END LOOP;
RETURN result_table;
END;
/
 
CREATE OR REPLACE PROCEDURE SHOW_TABLE_OBJECTS (table_name IN VARCHAR2,
final_rc OUT SYS_REFCURSOR)
IS
query_text VARCHAR2 (1000) ;
BEGIN
query_text := '
SELECT ''foreign_key'' AS "object_type",
CONSTRAINT_NAME AS "object_name"
FROM ALL_CONSTRAINTS
WHERE OWNER = USER
AND TABLE_NAME = ''_FP_TABLE_NAME_PLACEHOLDER_''
AND CONSTRAINT_TYPE = ''R''
UNION
SELECT ''trigger'' AS "object_type",
TRIGGER_NAME AS "object_name"
FROM ALL_TRIGGERS
WHERE OWNER = USER
AND TABLE_NAME = ''_FP_TABLE_NAME_PLACEHOLDER_''
UNION 
SELECT ''view'' AS "object_type",
"VIEW_NAME" AS "object_name"
FROM TABLE(ALL_VIEWS_VARCHAR2)
-- This is where we use that previously created supplementary function.
WHERE "TEXT" LIKE ''%"_FP_TABLE_NAME_PLACEHOLDER_"%''';
query_text := REPLACE (query_text, '_FP_TABLE_NAME_PLACEHOLDER_', table_name) ;
OPEN final_rc FOR query_text;
END ;
/

DECLARE
rc SYS_REFCURSOR;
object_type VARCHAR2 (500) ;
object_name VARCHAR2 (500) ;
BEGIN
SHOW_TABLE_OBJECTS ('subscriptions', rc) ;

LOOP
FETCH rc INTO object_type, object_name;
EXIT WHEN rc%NOTFOUND ;
DBMS_OUTPUT.PUT_LINE(object_type || ' | ' || object_name) ;
END LOOP;
CLOSE rc;
END ;

/* 04 - Using Stored Procedures for Performance Optimization */
/* 8. Create a stored procedure that is scheduled to update
“books_statistics” table (see “Using Caching Views and Tables
to Select Data” topic’s Task 1) every hour. */
DROP PROCEDURE UPDATE_BOOKS_STATISTICS
CREATE OR REPLACE PROCEDURE UPDATE_BOOKS_STATISTICS
AS
rows_count NUMBER;
BEGIN
SELECT COUNT(1) INTO rows_count
FROM ALL_TABLES
WHERE OWNER = USER
AND TABLE_NAME = 'books_statistics';
-- Let’s check if the table exists.
IF (rows_count = 0)
THEN
RAISE_APPLICATION_ERROR (-20001, 'The "books statistics" table is missing.') ;
RETURN ;
END IF;
-- Here we update the table.
UPDATE "books_statistics"
SET ("total", "given", "rest") =
(SELECT NVL("total", 0) AS "total",
NVL("given", 0) AS "given",
NVL("total" - "given", 0) AS "rest"
FROM (SELECT (SELECT SUM("b_quantity")
FROM "books") AS "total",
(SELECT COUNT ("sb_book")
FROM "subscriptions"
WHERE "sb_is_active" = 'Y') AS "given"
FROM dual) "prepared_data") ;
END ;
/

EXECUTE UPDATE_BOOKS_STATISTICS

BEGIN
DBMS_SCHEDULER.CREATE_JOB (
job_name => 'hourly_update_books_statistics',
job_type => 'STORED_PROCEDURE' ,
job_action => 'UPDATE_BOOKS_STATISTICS',
start_date => '13-05-22 1.00.00 AM',
repeat_interval => ' FREQ=HOURLY ; INTERVAL=1' ,
auto_drop => FALSE,
enabled => TRUE);
END ;

SELECT * FROM ALL_SCHEDULER_JOBS WHERE OWNER=USER

/* 9. Create a stored procedure that is scheduled to optimize
(compress) all database tables once per day.*/
CREATE OR REPLACE PROCEDURE OPTIMIZE_ALL_TABLES
AS
table_name VARCHAR(150) := '';
query_text VARCHAR(1000) := '';
CURSOR tables_cursor IS
SELECT TABLE_NAME AS "table_name"
FROM ALL_TABLES
WHERE OWNER=USER;
BEGIN
FOR one_row IN tables_cursor
LOOP
-- Here we enable each table optimization.
query_text := 'ALTER TABLE "' || one_row."table_name" ||
'" ENABLE ROW MOVEMENT' ;
DBMS_OUTPUT.PUT_LINE('Enabling row movement for "' ||
one_row."table_name" || '"...');
EXECUTE IMMEDIATE query_text;
-- Here we optimize each table.
query_text := 'ALTER TABLE "' || one_row."table_name" ||
'" SHRINK SPACE COMPACT CASCADE' ;
DBMS_OUTPUT.PUT_LINE('Performing SHRINK SPACE COMPACT CASCADE on "' ||
one_row."table_name" || '"...');
EXECUTE IMMEDIATE query_text;
-- Here we disable each table optimization.
query_text := 'ALTER TABLE "' || one_row."table_name" ||
'" DISABLE ROW MOVEMENT' ;
DBMS_OUTPUT.PUT_LINE('Disabling row movement for "' ||
one_row."table_name" || '" ... ');
EXECUTE IMMEDIATE query_text;
END LOOP;
END;
/

SET SERVEROUTPUT ON;
EXECUTE OPTIMIZE_ALL_TABLES;

BEGIN
DBMS_SCHEDULER.CREATE_JOB (
job_name => 'dayly_optimize_all_tables',
job_type => 'STORED_PROCEDURE' ,
job_action => 'OPTIMIZE_ALL_TABLES',
start_date => '13-05-22 1.00.00 AM',
repeat_interval => ' FREQ=DAYLY ; INTERVAL=1' ,
auto_drop => FALSE,
enabled => TRUE);
END ;

SELECT * FROM ALL_SCHEDULER_JOBS WHERE OWNER=USER
 
/*  05 - Using Stored Procedures to Manipulate Database Objects */
/* 10. Create a stored procedure that automatically creates and
populates with data “books_statistics” table (see “Using
Caching Views and Tables to Select Data” topic’s Task 1).*/
CREATE OR REPLACE PROCEDURE CREATE_BOOKS_STATISTICS
AS
table_found NUMBER(1) :=0;
BEGIN
-- Check, if table exists.
SELECT COUNT(1) INTO table_found 
FROM ALL_TABLES
WHERE OWNER=USER
AND TABLE_NAME = 'books_statistics';
IF (table_found = 0)
THEN
-- Create table, if not exists.
/* Oracle does not allow to compile a procedure referencing non-existing
database objects. So, we “hide” such reference inside a dynamic query.*/
EXECUTE IMMEDIATE 'CREATE TABLE "books_statistics"
(
"total" NUMBER (10) ,
"given" NUMBER(10),
"rest" NUMBER(10)
)';
EXECUTE IMMEDIATE 'INSERT INTO "books_statistics"
("total",
"given",
"rest")
SELECT "total",
"given",
("total" - "given") AS "rest"
FROM (SELECT SUM("b_quantity") AS "total"
FROM "books")
JOIN (SELECT COUNT("sb_book") AS "given"
FROM "subscriptions"
WHERE "sb_is_active" = ''Y'')
ON 1 =1';
ELSE
EXECUTE IMMEDIATE 'UPDATE "books_statistics"
SET ("total", "given", "rest") =
(SELECT "total",
"given",
("total" - "given") AS "rest"
FROM (SELECT SUM("b_quantity") AS "total"
FROM "books")
JOIN (SELECT COUNT("sb_book") AS "given"
FROM "subscriptions"
WHERE "sb_is_active" = ''Y'')
ON 1 =1';
END IF;
END;
/

DROP TABLE "books_statistics";
EXECUTE CREATE_BOOKS_STATISTICS;
SELECT * FROM "books_statistics";

/* 11. Create a stored procedure that automatically creates and
populates with data “tables_rc” table that contains all database
tables names along with records count for each table.*/
CREATE OR REPLACE PROCEDURE CACHE_TABLES_RC
AS
table_name VARCHAR (150) := '';
table_rows NUMBER(10) := 0;
table_found NUMBER (1) := 0;
query_text VARCHAR (1000) := '';
CURSOR tables_cursor IS
SELECT TABLE_NAME AS "table_name"
FROM ALL_TABLES
WHERE OWNER=USER ;
BEGIN
-- Check, if table exists.
SELECT COUNT(1) INTO table_found
FROM ALL_TABLES
WHERE OWNER=USER
AND TABLE_NAME = 'tables_rc';
IF (table_found = 0)
THEN
-- Create table, if not exists.
EXECUTE IMMEDIATE 'CREATE TABLE "tables_rc"
("table_name" VARCHAR (200),
"rows_count" NUMBER (10))';
END IF;
-- Clear table. WARNING! In real production environment some applications may crash if they don’t expect this table to be empty.
EXECUTE IMMEDIATE 'TRUNCATE TABLE "tables_rc"';
FOR one_row IN tables_cursor
LOOP 
query_text := 'SELECT COUNT(1) FROM "' || one_row."table_name" || '"';
-- Populate table with data.
EXECUTE IMMEDIATE query_text INTO table_rows;
query_text := 'INSERT INTO "tables_rc" ("table_name", "rows_count")
VALUES (''' || one_row."table_name" || ''', ' || table_rows || ')';
EXECUTE IMMEDIATE query_text;
END LOOP;
END ;
/ 
/* Oracle does not allow to compile a procedure referencing non-existing
database objects. So, we “hide” such reference inside a dynamic query. */

EXECUTE CACHE_TABLES_RC;
SELECT * FROM "tables_rc";
   


 