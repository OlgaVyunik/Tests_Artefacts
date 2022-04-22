/* 01 - 01 - Using Non-Caching Views to Select Data*/
/* 1. Create a view to simplify access to the data produced by the
following queries (see Task 4 in “JOINs with MIN, MAX, AVG,
range”)..*/
CREATE OR REPLACE VIEW "first_book" AS /* Just add this line to the beginning of the query*/
WITH "step_1"
	AS (SELECT "sb_subscriber", MIN("sb_start") AS "min_sb_start"
		FROM "subscriptions"
		GROUP BY "sb_subscriber"),
	"step_2"
	AS (SELECT "subscriptions"."sb_subscriber", MIN("sb_id") AS "min_sb_id"
		FROM "subscriptions"
		JOIN "step_1" ON "subscriptions"."sb_subscriber" = "step_1"."sb_subscriber"
		AND "subscriptions"."sb_start" = "step_1"."min_sb_start"
		GROUP BY "subscriptions"."sb_subscriber", "min_sb_start"),
	"step_3"
	AS (SELECT "subscriptions"."sb_subscriber", "sb_book"
		FROM "subscriptions"
		JOIN "step_2" ON "subscriptions"."sb_id" = "step_2"."min_sb_id")
SELECT "s_id", "s_name", "b_name"
FROM "step_3"
JOIN "subscribers" ON "sb_subscriber" = "s_id"
JOIN "books" ON "sb_book" = "b_id";
/* The result would be achiveable via query:*/
SELECT *
FROM "first_book";

/* 2. Create a view to show authors along with their books quantity
taking into account only authors with two or more books.*/
CREATE OR REPLACE VIEW "authors_with_more_than_one_book" AS
SELECT "a_id", "a_name", COUNT("b_id") AS "books_in_library"
FROM "authors"
JOIN "m2m_books_authors" USING ("a_id")
GROUP BY "a_id", "a_name"
HAVING COUNT("b_id") > 1;

SELECT *
FROM "authors_with_more_than_one_book";

/* 02 - Using Caching Views and Tables to Select Data*/
/* 3. Create a view to speed up the retrieval of the following data:
- total books count;
- taken books count;
- available books count.*/

-- Old versions of triggers deletion (convenient for debug):
DROP MATERIALIZED VIEW "books_statistics";

-- Materialized view creation:
CREATE MATERIALIZED VIEW "books_statistics"
BUILD IMMEDIATE
REFRESH FORCE
/* ×òîáû îáíîâëÿëîñü àâòîìàòè÷åñêè ïî èñòå÷åíèè âðåìåíè*/
START WITH (SYSDATE) NEXT (SYSDATE + 1/1440) 
AS
    SELECT "total",
        "given",
        "total" - "given" AS "rest"
    FROM (SELECT SUM("b_quantity") AS "total"
        FROM "books")
    JOIN (SELECT COUNT("sb_book") AS "given"
        FROM "subscriptions"
        WHERE "sb_is_active" = 'Y')
        ON 1 = 1
;

SELECT *
FROM "books_statistics";

SELECT *
FROM "subscriptions";

/* 4. Create a view to speed up the retrieval of “subscriptions” table
data in “human-readable form” (i.e. with books names,
subscribers names, etc.....)*/
-- Old version of view deletion (convenient for debug)
DROP MATERIALIZED VIEW "subscriptions_ready";

-- Materialized view creation:
CREATE MATERIALIZED VIEW "subscriptions_ready"
BUILD IMMEDIATE
REFRESH FORCE
START WITH (SYSDATE) NEXT (SYSDATE + 1/1440)
AS
SELECT "sb_id",
    "s_name" AS "sb_subscriber",
    "b_name" AS "sb_book",
    "sb_start",
    "sb_finish",
    "sb_is_active"
FROM "books"
JOIN "subscriptions" ON "b_id" = "sb_book"
JOIN "subscribers" ON "sb_subscriber" = "s_id";

SELECT *
FROM "subscriptions_ready";

/* 03 - Using Views to Obscure Database Structures and Data Values */
/* 5. Create a view on "subscriptions" table to hide the information about subscribers. */
CREATE VIEW "subscriptions_anonymous"
AS
	SELECT "sb_id",
		"sb_book",
		"sb_start",
		"sb_finish",
		"sb_is_active"
    FROM "subscriptions";

SELECT *
FROM "subscriptions_anonymous";

/* 6. Create a view on "subscriptions" table to present all dates in Unixtime format. */
CREATE VIEW "subscriptions_unixtime"
AS
	SELECT "sb_id",
        "sb_subscriber",
		"sb_book",
		(("sb_start" - TO_DATE('01-01-1970', 'DD-MM-YYYY')) * 86400) AS "sb_start",
		(("sb_finish"- TO_DATE('01-01-1970', 'DD-MM-YYYY')) * 86400) AS "sb_finish",
		"sb_is_active"
    FROM "subscriptions";

SELECT *
FROM "subscriptions_unixtime";

/* 7. Create a view on "subscriptions" table to present all dates in "YYYY-MM-DD DW" format, where "DW" is a full day of week name (e.g., "Sunday", "Monday", etc.)*/
CREATE VIEW "subscriptions_data_wd"
AS
	SELECT "sb_id",
        "sb_subscriber",
		"sb_book",
        "sb_start" || ' - ' ||	TO_CHAR("sb_start", 'Day') AS "sb_start_dw",
        "sb_finish" || ' - ' || TO_CHAR("sb_finish", 'Day') AS "sb_finish_dw",
		"sb_is_active"
    FROM "subscriptions";

SELECT *
FROM "subscriptions_data_wd";

/* 04 - Using Updatable Views to Modify Data */
/* 8. Create a view on “subscribers” table to present all subscribers’
names in upper case while allowing to modify “subscribers”
table via operations with the view.*/
-- View creation (allows deletion only):
CREATE VIEW "subscribers_upper_case"
AS
    SELECT "s_id", UPPER("s_name") AS "s_name"
    FROM "subscribers"
    
-- INSERT trigger creation:
CREATE OR REPLACE TRIGGER "subscribers_upper_case_ins"
INSTEAD OF INSERT ON "subscribers_upper_case"
FOR EACH ROW
BEGIN
    INSERT INTO "subscribers"
        ("s_id",
        "s_name")
    VALUES  (:new."s_id",
             :new."s_name") ;
END;
/*In Oracle primary key auto increment is based on triggers and sequences,
so we don’t need to calculate anything ourselves.*/

-- UPDATE trigger creation:
CREATE OR REPLACE TRIGGER "subscribers_upper_case_upd"
INSTEAD OF INSERT ON "subscribers_upper_case"
FOR EACH ROW
BEGIN
    UPDATE "subscribers"
    SET "s_id" = :new."s_id",
        "s_name" = :new."s_name"
    WHERE "s_id" = ":old."s_id";
END 
/*In Oracle we use "row-level" triggers to avoid MS SQL limitation (in case of the primary key modification)*/
 
SELECT *
FROM "subscribers_upper_case";
 
/* 9. Create a view on “subscriptions” table to present subscription
start and finish dates as a single string while allowing to modify
“subscriptions” table via operations with the view.*/
-- View creation (allows deletion only):
CREATE VIEW "subscriptions_wcd"
AS
    SELECT "sb_id",
        "sb_subscriber",
		"sb_book",
		TO_CHAR("sb_start", 'YYYY-MM-DD') || ' - ' ||
        TO_CHAR("sb_finish",'YYYY-MM-DD') AS "sb_dates",
		"sb_is_active"
    FROM "subscriptions";
    
SELECT *
FROM "subscriptions_wcd";

-- INSERT trigger creation:
CREATE OR REPLACE TRIGGER "subscriptions_wcd_ins"
INSTEAD OF INSERT ON "subscriptions_wcd"
FOR EACH ROW
BEGIN
    INSERT INTO "subscriptions"
        ("sb_id",
        "sb_subscriber",
		"sb_book",
		"sb_start",
		"sb_finish",
		"sb_is_active")
    VALUES  (:new."sb_id",
             :new."sb_subscriber",
             :new."sb_book",
             TO_DATE(SUBSTR(:new."sb_dates", 1, (INSTR(:new."sb_dates", ' ') - 1)), 'YYYY-MM-DD'),
             TO_DATE(SUBSTR(:new."sb_dates", (INSTR(:new."sb_dates", ' ') + 3)), 'YYYY-MM-DD'),
             :new."sb_is_active");
END;

-- UPDATE trigger creation:
CREATE OR REPLACE TRIGGER "subscriptions_wcd_upd"
INSTEAD OF INSERT ON "subscriptions_wcd"
FOR EACH ROW
BEGIN
    UPDATE "subscriptions"
    SET "sb_is" = :new."sb_id",
         "sb_subscriber" = :new."sb_subscriber",
         "sb_book" = :new."sb_book",
         "sb_start" = TO_DATE(SUBSTR(:new."sb_dates", 1, (INSTR(:new."sb_dates", ' ') - 1)), 'YYYY-MM-DD'),
         "sb_finish" = TO_DATE(SUBSTR(:new."sb_dates", (INSTR(:new."sb_dates", ' ') + 3)), 'YYYY-MM-DD'),
         "sb_is_active" = :new."sb_is_active"
    WHERE "sb_id" = ":old."sb_id";
END ;
/*In Oracle we use "row-level" triggers to avoid MS SQL limitation (in case of the primary key modification)*/

/* 05 - Using Triggers on Views to Modify Data*/
/* 10. Create a view on “subscribers” table to present all the data in
“human-readable” form (i.e. with explicit names/titles instead
of ids) while allowing to modify “subscribers” table via
operations with the view.*/
-- View creation
CREATE VIEW "subscriptions_with_text"
AS
SELECT "sb_id",
        "s_name" AS "sb_subscriber",
        "b_name" AS "sb_book",
        "sb_start",
        "sb_finish",
        "sb_is_active"
FROM "subscriptions"
JOIN "subscribers" ON "sb_subscriber" = "s_id"
JOIN "books" ON "sb_book" = "b_id"

-- INSERT trigger creation:
CREATE OR REPLACE TRIGGER "subscriptions_with_text_ins"
INSTEAD OF INSERT ON "subscriptions_with_text"
FOR EACH ROW
BEGIN /*As names or titles are not unique, we allow only ids usage here*/
    IF  ((REGEXP_INSTR(:new."sb_subscriber", '[^0-9]') > 0)
    OR (REGEXP_INSTR(:new."sb_book", '[^0-9]') > 0))
    THEN
    RAISE_APPLICATION_ERROR(-20001, 'Use digital identifiers for "sb_subscriber" and "sb_book". Do not use subscribers'' names or books'' titles') ;
    ROLLBACK;
END IF;
INSERT INTO "subscriptions"
            ("sb_id",
            "sb_subscriber",
            "sb_book",
            "sb_start",
            "sb_finish",
            "sb_is_active")
VALUES (:new."sb_id",
        :new."sb_subscriber",
        :new."sb_book",
        :new."sb_start",
        :new."sb_finish",
        :new."sb_is_active") ;
END;

-- UPDATE trigger creation:
CREATE OR REPLACE TRIGGER "subscriptions_with_text_upd"
INSTEAD OF UPDATE ON "subscriptions_with_text"
FOR EACH ROW
BEGIN
IF ((:old."sb_subscriber" != :new."sb_subscriber")
AND (REGEXP_INSTR(:new."sb_subscriber", '[^0-9]') > 0 ))
OR ((:old."sb_book" != :new."sb_book")
AND (REGEXP_INSTR(:new."sb_book", '[^0-9]') > 0))
THEN
RAISE_APPLICATION_ERROR(-20001, 'Use digital identifiers for
"sb_subscriber" and "sb_book". Do not use subscribers'' names
or books'' titles');
ROLLBACK;
END IF; 

UPDATE "subscriptions"
SET "sb_id" = :new."sb_id",
    "sb_subscriber" = 
            CASE
            WHEN (REGEXP_INSTR(:new."sb_subscriber", '[^0-9]') = 0)
            THEN :new."sb_subscriber"
            ELSE "sb_subscriber" || N''
            END,
    "sb_book" =
            CASE
            WHEN (REGEXP_INSTR(:new."sb_book", '[^0-9]') = 0)
            THEN :new."sb_book"
            ELSE "sb_book" || N''
            END,
    "sb_start" = :new."sb_start",
    "sb_finish" = :new."sb_finish",
    "sb_is_active" = :new."sb_is_active"
WHERE "sb_id" = :old."sb_id";
END;

-- DELETE trigger creation:
/*1) Like MS SQL, Oracle searches for records match before trigger
activation, so we can not handle string names/titles (this problem has
no solution).
2) We can not search records for deletion based on ids (as the view
selects names/titles), and we can not use names/titles as they are not
unique (this problem has no solution in Oracle).*/
CREATE OR REPLACE TRIGGER "subscriptions_with_text_del"
INSTEAD OF DELETE ON "subscriptions_with_text"
FOR EACH ROW
BEGIN
DELETE FROM "subscriptions"
WHERE "sb_id" = :old."sb_id";
END;

/* 11. Create a view to select books’ titles along with books’ genres
while allowing to add new genres via operations with the view.*/
-- View creation:
CREATE VIEW "books_with_genres"
AS
SELECT "b_id", "b_name",
        UTL_RAW.CAST_TO_NVARCHAR2
        (LISTAGG ( UTL_RAW.CAST_TO_RAW("g_name"),
                UTL_RAW.CAST_TO_RAW(N', ')
                )
        WITHIN GROUP (ORDER BY "g_name")
        )
AS "genres"
FROM "books"
JOIN "m2m_books_genres" USING ("b_id")
JOIN "genres" USING ("g_id")
GROUP BY "b_id", "b_name";

SELECT *
FROM "books_with_genres";

-- INSERT trigger creation:
CREATE OR REPLACE TRIGGER "books_with_genres_ins"
INSTEAD OF INSERT ON "books_with_genres"
FOR EACH ROW
BEGIN
INSERT INTO "genres"
            ("g_name")
VALUES (:new."genres") ;
END ;
