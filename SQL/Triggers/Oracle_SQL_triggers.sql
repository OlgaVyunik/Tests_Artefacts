/* 01 - Using Triggers to Update Caching Tables and Fields*/
/* 1. Modify “subscribers” table to store the last visit date for each
subscriber (and keep that data up-to-date).*/
-- Table modification:
ALTER TABLE "subscribers"
ADD ("s_last_visit" DATE DEFAULT NULL NULL) ;

-- Data initialization:
UPDATE "subscribers" "outer"
SET "s_last_visit" =
    (
    SELECT "last_visit"
    FROM "subscribers"
    LEFT JOIN (SELECT "sb_subscriber",
    MAX("sb_start") AS "last_visit"
    FROM "subscriptions"
    GROUP BY "sb_subscriber") "prepared_data"
    ON "s_id" = "sb_subscriber"
    WHERE "outer"."s_id" = "sb_subscriber") ;

 SELECT *
 FROM "subscribers";
 
 -- Trigger for all operations with subscriptions:
CREATE TRIGGER "last_visit_on_scs_ins_upd_del"
AFTER INSERT OR UPDATE OR DELETE
ON "subscriptions"
BEGIN
UPDATE "subscribers" "outer" 
SET "s_last_visit" =
    (
    SELECT "last_visit"
    FROM "subscribers"
    LEFT JOIN (SELECT "sb_subscriber",
    MAX("sb_start") AS "last_visit"
    FROM "subscriptions"
    GROUP BY "sb_subscriber") "prepared_data"
    ON "s_id" = "sb_subscriber"
    WHERE "outer"."s_id" = "sb_subscriber") ;
END ;

/* 2. Create “averages” table to store the following up-to-date information:
- average books count for “taken by a subscriber”;
- average days count for “a subscriber keeps a book”;
- average books count for “returned by a subscriber”.*/
-- Table creation:
CREATE TABLE "averages"
(
"books_taken" DOUBLE PRECISION NOT NULL,
"days_to_read" DOUBLE PRECISION NOT NULL,
"books_returned" DOUBLE PRECISION NOT NULL
)
-- Table truncation:
TRUNCATE TABLE "averages";

-- Data initialization:
INSERT INTO "averages"
    ("books_taken",
    "days_to_read",
    "books_returned")
SELECT ( "active_count" / "subscribers_count" ) AS "books_taken",
    ( "days_sum" / "inactive_count" ) AS "days_to_read",
    ( "inactive_count" / "subscribers_count" ) AS "books_returned"
FROM (SELECT COUNT("s_id") AS "subscribers_count"
    FROM "subscribers") "tmp_subscribers_count",
    (SELECT COUNT ("sb_id") AS "active_count"
    FROM "subscriptions"
    WHERE "sb_is_active" = 'Y') "tmp_active_count",
    (SELECT COUNT ("sb_id") AS "inactive_count"
    FROM "subscriptions"
    WHERE "sb_is_active" = 'N') "tmp_inactive_count",
    (SELECT SUM("sb_finish" - "sb_start") AS "days_sum"
    FROM "subscriptions"
    WHERE "sb_is_active" = 'N') "tmp_days_sum";

SELECT *
FROM "averages"

-- Trigger for subscribers insertion and deletion:
CREATE TRIGGER "upd_avgs_on_sbrs_ins_del"
AFTER INSERT OR DELETE
ON "subscribers"
BEGIN
MERGE INTO "averages"
USING
    (
    SELECT ( "active_count" / "subscribers_count" ) AS "books_taken",
    ( "days_sum" / "inactive_count" ) AS "days_to_read",
    ( "inactive_count" / "subscribers_count" ) AS "books_returned"
FROM (SELECT COUNT("s_id") AS "subscribers_count"
    FROM "subscribers") "tmp_subscribers_count",
    (SELECT COUNT ("sb_id") AS "active_count"
    FROM "subscriptions"
    WHERE "sb_is_active" = 'Y') "tmp_active_count",
    (SELECT COUNT ("sb_id") AS "inactive_count"
    FROM "subscriptions"
    WHERE "sb_is_active" = 'N') "tmp_inactive_count",
    (SELECT SUM("sb_finish" - "sb_start") AS "days_sum"
    FROM "subscriptions"
    WHERE "sb_is_active" = 'N') "tmp_days_sum"
) "tmp" ON (1=1)
WHEN MATCHED THEN UPDATE
SET "averages"."books_taken" = "tmp"."books_taken",
    "averages"."days_to_read" = "tmp"."days_to_read",
    "averages"."books_returned" = "tmp"."books_returned" ;
END ;

-- Trigger for all operations with subscriptions:
CREATE TRIGGER "upd_avgs_on_sbps_ins_upd_del"
AFTER INSERT OR DELETE
ON "subscriptions"
BEGIN
MERGE INTO "averages"
USING
    (
    SELECT ( "active_count" / "subscribers_count" ) AS "books_taken",
    ( "days_sum" / "inactive_count" ) AS "days_to_read",
    ( "inactive_count" / "subscribers_count" ) AS "books_returned"
FROM (SELECT COUNT("s_id") AS "subscribers_count"
    FROM "subscribers") "tmp_subscribers_count",
    (SELECT COUNT ("sb_id") AS "active_count"
    FROM "subscriptions"
    WHERE "sb_is_active" = 'Y') "tmp_active_count",
    (SELECT COUNT ("sb_id") AS "inactive_count"
    FROM "subscriptions"
    WHERE "sb_is_active" = 'N') "tmp_inactive_count",
    (SELECT SUM("sb_finish" - "sb_start") AS "days_sum"
    FROM "subscriptions"
    WHERE "sb_is_active" = 'N') "tmp_days_sum"
) "tmp" ON (1=1)
WHEN MATCHED THEN UPDATE
SET "averages"."books_taken" = "tmp"."books_taken",
    "averages"."days_to_read" = "tmp"."days_to_read",
    "averages"."books_returned" = "tmp"."books_returned" ;
END ;

/* 02 - Using Triggers to Ensure Data Consistency */
/* 3. Modify “subscribers” table to store the number of books taken
by each subscriber (and keep that data up-to-date).*/
-- Table modification:
ALTER TABLE "subscribers"
ADD ("s_books" INT DEFAULT 0 NOT NULL) ;

-- Data initialization:
UPDATE "subscribers"
SET "s_books" = NVL(
(SELECT COUNT("sb_id") AS "s_has_books"
FROM "subscriptions"
WHERE "sb_is_active" = 'Y'
AND "sb_subscriber" = "s_id"
GROUP BY "sb_subscriber"), 0) ;

SELECT *
FROM "subscribers"

-- Trigger for subscriptions insertion:
CREATE OR REPLACE TRIGGER "s_has_books_on_sbps_ins"
AFTER INSERT
ON "subscriptions"
FOR EACH ROW
BEGIN
    IF (:new."sb_is_active" = 'Y') THEN
    UPDATE "subscribers"
    SET "s_books" = "s_books" + 1
    WHERE "s_id" = :new."sb_subscriber";
    END IF;
END;

-- Trigger for subscriptions deletion:
CREATE OR REPLACE TRIGGER "s_has_books_on_sbps_del"
AFTER DELETE
ON "subscriptions"
FOR EACH ROW
BEGIN
    IF (:old."sb_is_active" = 'Y') THEN
    UPDATE "subscribers"
    SET "s_books" = "s_books" - 1
    WHERE "s_id" = :old."sb_subscriber";
    END IF;
END;

-- Trigger for subscriptions update:
CREATE OR REPLACE TRIGGER "s_has_books_on_sbps_upd"
AFTER UPDATE
ON "subscriptions"
FOR EACH ROW
BEGIN
-- A) Same subscriber, Y -> N
 IF (:old."sb_subscriber" = :new."sb_subscriber") AND
    (:old."sb_is_active" = 'Y') AND
    (:new."sb_is_active" = 'N')  THEN
    UPDATE "subscribers"
    SET "s_books" = "s_books" - 1
    WHERE "s_id" = :old."sb_subscriber";
    END IF;
-- B) Same subscriber, N -> Y
IF (:old."sb_subscriber" = :new."sb_subscriber") AND
    (:old."sb_is_active" = 'N') AND
    (:new."sb_is_active" = 'Y')  THEN
    UPDATE "subscribers"
    SET "s_books" = "s_books" + 1
    WHERE "s_id" = :old."sb_subscriber";
    END IF;
-- C) Different subscriber, Y -> Y 
IF (:old."sb_subscriber" != :new."sb_subscriber") AND
    (:old."sb_is_active" = 'Y') AND
    (:new."sb_is_active" = 'Y')  THEN
    UPDATE "subscribers"
    SET "s_books" = "s_books" - 1
    WHERE "s_id" = :old."sb_subscriber";
    UPDATE "subscribers"
    SET "s_books" = "s_books" + 1
    WHERE "s_id" = :new."sb_subscriber";
    END IF;
-- D) Different subscriber, Y -> N
 IF (:old."sb_subscriber" != :new."sb_subscriber") AND
    (:old."sb_is_active" = 'Y') AND
    (:new."sb_is_active" = 'N')  THEN
    UPDATE "subscribers"
    SET "s_books" = "s_books" - 1
    WHERE "s_id" = :old."sb_subscriber";
    END IF; 
-- E) Different subscriber, N -> Y
IF (:old."sb_subscriber" != :new."sb_subscriber") AND
    (:old."sb_is_active" = 'N') AND
    (:new."sb_is_active" = 'Y')  THEN
    UPDATE "subscribers"
    SET "s_books" = "s_books" + 1
    WHERE "s_id" = :new."sb_subscriber";
    END IF;
END;

/* 4. Modify “genres” table to store the number of books in each
genre (and keep that data up-to-date).*/
-- Table modification:
ALTER TABLE "genres"
ADD ("g_books" NUMBER(10) DEFAULT 0 NOT NULL);

-- Data initialization:
UPDATE "genres" "outer"
SET "g_books" =
    NVL((SELECT COUNT("b_id") AS "g_has_books"
    FROM "m2m_books_genres"
    WHERE "outer"."g_id" = "g_id"
    GROUP BY "g_id"), 0);
    
SELECT *
FROM "genres";

-- Trigger for books-genres association insertion:
CREATE TRIGGER "g_has_bks_on_m2m_b_g_ins"
AFTER INSERT
ON "m2m_books_genres"
FOR EACH ROW
BEGIN
UPDATE "genres"
SET "g_books" = "g_books" + 1
WHERE "g_id" = :new."g_id";
END;

-- Trigger for books-genres association update:
CREATE TRIGGER "g_has_bks_on_m2m_b_g_upd"
AFTER UPDATE
ON "m2m_books_genres"
FOR EACH ROW
BEGIN
    UPDATE "genres"
    SET "g_books" = "g_books" + 1
    WHERE "g_id" = :new."g_id";
    UPDATE "genres"
    SET "g_books" = "g_books" - 1
    WHERE "g_id" = :old."g_id";
END;

-- Trigger for books-genres association deletione:
CREATE TRIGGER "g_has_bks_on_m2m_b_g_del"
AFTER DELETE
ON "m2m_books_genres"
FOR EACH ROW
BEGIN
    UPDATE "genres"
    SET "g_books" = "g_books" - 1
    WHERE "g_id" = :old."g_id";
END;

/* 03 - Using Triggers to Control Data Modification*/
/* 5. Create a trigger to prevent the following situations with subscriptions:
- subscription start date is in the future;
- subscription end date is in the past (for INSERT operations
only);
- subscription end date is less than subscription start date.*/
-- Trigger for subscription creation:
CREATE TRIGGER "subscriptions_control_ins"
AFTER INSERT
ON "subscriptions"
FOR EACH ROW
BEGIN
-- Block aby subscription with the start date is in the future:
IF :new."sb_start" > TRUNC(SYSDATE)
THEN
RAISE_APPLICATION_ERROR (-20001, 'Date ' || :new."sb_start" ||
                        ' for subscription ' || :new."sb_id" ||
                        ' activation is in the future.');
END IF;
-- Block aby subscription with the end date is in the past:
IF :new."sb_finish" < TRUNC(SYSDATE)
THEN
RAISE_APPLICATION_ERROR (-20002, 'Date ' || :new."sb_finish" ||
                        ' for subscription ' || :new."sb_id" ||
                        ' deactivation is in the past.');
END IF;
-- Block any subscription with the end date less than the start date:
IF :new."sb_finish" < :new."sb_start"
THEN
RAISE_APPLICATION_ERROR(-20003, 'Date ' || :new."sb_finish" ||
                        ' for subscription ' || :new."sb_id" ||
                        ' deactivation is less than the date
                        for its activation (' ||
                        :new."sb_start" || ').');
END IF;
END;

-- Trigger for subscription modification: (we don't need a DELETE-trigger as it's impossible to violate any mentioned rules during DELETE operation)
CREATE TRIGGER "subscriptions_control_upd"
AFTER UPDATE
ON "subscriptions"
FOR EACH ROW
BEGIN
    -- Block aby subscription with the start date is in the future:
IF :new."sb_start" > TRUNC(SYSDATE)
    THEN
    RAISE_APPLICATION_ERROR(-20001, 'Date ' || :new."sb_start" ||
    ' for subscription ' || :new."sb_id" ||
    ' activation is in the future.') ;
END IF;

    -- Block any subscription with the end date less than the start date:
IF :new."sb_finish" < :new."sb_start"
    THEN
    RAISE_APPLICATION_ERROR(-20003, 'Date ' || :new."sb_finish" ||
    ' for subscription ' || :new."sb_id" ||
    ' deactivation is less than the date for its activation (' ||
    :new."sb_start" || ').');
END IF;
END;

/* 6. Create a trigger to prevent creation of a new subscription for a
subscriber already having 10 (and more) books taken.*/
CREATE TRIGGER "sbs_ctr_10_bks_ins_upd_OK" 
BEFORE INSERT OR UPDATE
ON "subscriptions"
FOR EACH ROW
DECLARE
PRAGMA AUTONOMOUS_TRANSACTION;
msg NCLOB;
BEGIN
SELECT NVL((SELECT (N'Subscriber ' || "s_name" || N' (id=' ||
                    "sb_subscriber" || N') already has ' ||
                    "sb_books" || N' books out of 10 allowed. ')
                    AS "message"
            FROM (SELECT "sb_subscriber",
                    COUNT ("sb_book") AS "sb_books"
                    FROM "subscriptions"
                    WHERE "sb_is_active" = 'Y'
                    AND "sb_subscriber" = :new."sb_subscriber"
                    GROUP BY "sb_subscriber"
                    HAVING COUNT ("sb_book") >= 10) "prepared_data"
            JOIN "subscribers"
            ON "sb_subscriber" = "s_id") ,
            '')
INTO msg FROM dual;
IF (LENGTH (msg) > 0)
THEN
RAISE_APPLICATION_ERROR (-20001, msg) ;
END IF;
END ;

/* 7. Create a trigger to prevent modifying a subscription from
inactive state back to active (i.e. from modifying “sb_is_active”
field value from “N” to “Y”).*/
CREATE TRIGGER "sbs_ctr_is_active"
BEFORE UPDATE
ON "subscriptions"
FOR EACH ROW
BEGIN
IF ((:old."sb_is_active" = 'N') AND (:new."sb_is_active" = 'Y'))
THEN
RAISE_APPLICATION_ERROR(-20001, 'It is prohibited to activate
                        previously deactivated subscriptions
                        (rule violated for subscription with
                        id ' || :new."sb_id" || ').');
END IF;
END ;

/* 04 - Using Triggers to Control Data Format and Values */
/* 8. Create a trigger to only allow registration of subscribers with a
dot and at least two words in their names.*/
CREATE TRIGGER "sbsrs_cntrl_name_ins_upd"
BEFORE INSERT OR UPDATE
ON "subscribers"
FOR EACH ROW
BEGIN
IF ((NOT REGEXP_LIKE(:new."s_name", '^[a-zA-Zà-ÿÀ-ß¸¨''-]+([^[a-zA-Zà-ÿÀ-ß¸¨''-]+[a-zA-Zà-ÿÀ-ß¸¨''.-]+){1,}$'))
OR (INSTRC(:new."s_name", '.', 1, 1) = 0))
THEN
RAISE_APPLICATION_ERROR(-20001, 'Subscribers name should contain
                        at least two words and one point, but the following name violates
                        this rule: ' || :new."s_name") ;
END IF;
END ;

/* 9. Create a trigger to only allow registration of books issued no
more than 100 years ago.*/
CREATE TRIGGER "books_cntrl_year_ins_upd"
BEFORE INSERT OR UPDATE
ON "books"
FOR EACH ROW
BEGIN
IF ((TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY')) - :new."b_year") > 100)
THEN
RAISE_APPLICATION_ERROR(-20001, 'The following issuing year is
more than 100 years in the past: ' || :new."b_year") ;
END IF;
END ;

/* 05 - Using Triggers to Correct Data On-the-Fly*/
/* 10. Create a trigger to check if there is a dot at the end of
subscriber’s name and to add a such dot if there is no one.*/
CREATE TRIGGER "sbsrs_name_lp_ins_upd"
BEFORE INSERT OR UPDATE
ON "subscribers"
FOR EACH ROW
DECLARE
new_value NVARCHAR2 (150) ;
BEGIN
IF (SUBSTR(:new."s_name", -1) <> '.')
THEN
new_value := CONCAT(:new."s_name", '.');
DBMS_OUTPUT.PUT_LINE (' Value [' || :new."s_name" ||
'] was automatically changed to [' || new_value || ']');
:new."s_name" := new_value;
END IF;
END ;

/* 11. Create a trigger to change the subscription end date to “current
date + two months” if the given end date is in the past or is less than the start date.*/
CREATE TRIGGER "sbscs_date_tm_ins_upd"
BEFORE INSERT OR UPDATE
ON "subscriptions"
FOR EACH ROW
DECLARE
new_value DATE ;
BEGIN
IF (:new."sb_finish" < :new."sb_start") OR (:new."sb_finish" < SYSDATE)
THEN
new_value := ADD_MONTHS(2, SYSDATE) ;
DBMS_OUTPUT.PUT_LINE('Value [' || :new."sb_finish" ||
'] was automatically changed to [' ||
TO_CHAR(new_value, 'YYYY-MM-DD') || ']');
:new."sb_finish" := new_value;
END IF;
END ;
