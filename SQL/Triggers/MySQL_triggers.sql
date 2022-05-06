/* 01 - Using Triggers to Update Caching Tables and Fields*/
/* 1. Modify “subscribers” table to store the last visit date for each
subscriber (and keep that data up-to-date).*/
-- Table modification:
ALTER TABLE subscribers
ADD COLUMN s_last_visit DATE NULL DEFAULT NULL AFTER s_name;

-- Data initialization:
UPDATE subscribers
LEFT JOIN (SELECT sb_subscriber,
				MAX(sb_start) AS last_visit
			FROM subscriptions
			GROUP BY sb_subscriber) AS prepared_data
		ON s_id = sb_subscriber
SET s_last_visit = last_visit;

SELECT *
FROM subscribers;

-- Old versions of triggers deletion (convenient for debug) :
DROP TRIGGER last_visit_on_subscriptions_ins;
DROP TRIGGER last_visit_on_subscriptions_upd;
DROP TRIGGER last_visit_on_subscriptions_del;

-- We have to tell MySQL where the real query ends:
DELIMITER $$

-- Trigger for subscriptions insertion:
CREATE TRIGGER “ast_visit_on_subscriptions_ins
AFTER INSERT
ON subscriptions
FOR EACH ROW
/*As cascade operations do not activate triggers in MySQL, you’ll
have to create some more triggers on “books” table yourself.*/
BEGIN
IF (SELECT IFNULL(s_last_visit, '1970-01-01')
	FROM subscribers
	WHERE s_id = NEW.sb_subscriber) < NEW.sb_start
THEN
	UPDATE subscribers
	SET  s_last_visit = NEW.sb_start
	WHERE s_id = NEW.sb_subscriber;
END IF;
END ;
$$
/*We modify only the subscriber with the new visit date. It helps to speed up the process a lot.*/

-- Trigger for subscriptions update:
CREATE TRIGGER last_visit_on_subscriptions_upd
AFTER UPDATE
ON subscriptions
FOR EACH ROW
BEGIN
UPDATE subscribers
LEFT JOIN (SELECT sb_subscriber,
				MAX(sb_start) AS last_visit
			FROM subscriptions
			GROUP BY sb_subscriber) AS prepared_data
	ON s_id = sb_subscriber
SET s_last_visit = last_visit
WHERE s_id IN (OLD.sb_subscriber, NEW.sb_subscriber);
END ;
$$ 
/* We modify only the subscriber with the new visit date. It helps to speed up the process a lot.*/

-- Trigger for subscriptions deletion:
CREATE TRIGGER last_visit_on_subscriptions_del
AFTER DELETE
ON subscriptions
FOR EACH ROW
BEGIN
UPDATE subscribers
LEFT JOIN (SELECT sb_subscriber,
				MAX(sb_start) AS last_visit
			FROM subscriptions
			GROUP BY sb_subscriber) AS prepared_data
	ON s_id = sb_subscriber
SET s_last_visit = last_visit
WHERE s_id = OLD.sb_subscriber ; 
END ;
$$
/*We modify only the subscriber with the new visit date. It helps to speed up the process a lot.*/

-- Now we have to restore normal query delimiter:
DELIMITER ;

/* 2. Create “averages” table to store the following up-to-date information:
- average books count for “taken by a subscriber”;
- average days count for “a subscriber keeps a book”;
- average books count for “returned by a subscriber”.*/
-- Table creation:
CREATE TABLE averages
(
books_taken DOUBLE NOT NULL,
days_to_read DOUBLE NOT NULL,
books_returned DOUBLE NOT NULL
);
-- Table truncation:
TRUNCATE TABLE averages ;

-- Data initialization:
INSERT INTO averages
	(books_taken,
	days_to_read,
	books_returned)
SELECT ( active_count / subscribers_count ) AS books_taken,
	( days_sum / inactive_count ) AS days_to_read,
	( inactive_count / subscribers_count ) AS books_returned
FROM (SELECT COUNT(s_id) AS subscribers_count
	FROM subscribers) AS tmp_subscribers_count,
	(SELECT COUNT(sb_id) AS active_count
	FROM subscriptions
	WHERE sb_is_active = 'Y') AS tmp_active_count,
	(SELECT COUNT(sb_id) AS inactive_count
	FROM subscriptions
	WHERE sb_is_active = 'N') AS tmp_inactive_count,
	(SELECT SUM(DATEDIFF(sb_finish, sb_start)) AS days_sum
	FROM subscriptions
	WHERE sb_is_active = 'N') AS tmp_days_sum;

SELECT *
FROM averages;

-- Old versions of triggers deletion (convenient for debug) :
DROP TRIGGER upd_avgs_on_subscribers_ins;
DROP TRIGGER upd_avgs_on_subscribers_del;

-- We have to tell MySQL where the real query ends:
DELIMITER $$

-- Trigger for subscribers insertion:
CREATE TRIGGER upd_avgs_on_subscribers_ins
AFTER INSERT
ON subscribers
FOR EACH ROW
BEGIN
UPDATE averages,
	(SELECT COUNT(s_id) AS subscribers_count
	FROM subscribers) AS tmp_subscribers_count,
	(SELECT COUNT(sb_id) AS active_count
	FROM subscriptions
	WHERE sb_is_active = 'Y') AS tmp_active_count,
	(SELECT COUNT(sb_id) AS inactive_count
	FROM subscriptions
	WHERE sb_is_active = 'N') AS tmp_inactive_count,
	(SELECT SUM(DATEDIFF(sb_finish, sb_start)) AS days_sum
	FROM subscriptions
	WHERE sb_is_active = 'N') AS tmp_days_sum
SET books_taken = active_count / subscribers_count,
	days_to_read = days_sum / inactive_count,
	books_returned = inactive_count / subscribers_count;
END;
$$

-- Trigger for subscribers deletion:
CREATE TRIGGER upd_avgs_on_subscribers_del
AFTER DELETE
ON subscribers
FOR EACH ROW
BEGIN
UPDATE averages,
	(SELECT COUNT(s_id) AS subscribers_count
	FROM subscribers) AS tmp_subscribers_count,
	(SELECT COUNT(sb_id) AS active_count
	FROM subscriptions
	WHERE sb_is_active = 'Y') AS tmp_active_count,
	(SELECT COUNT(sb_id) AS inactive_count
	FROM subscriptions
	WHERE sb_is_active = 'N') AS tmp_inactive_count,
	(SELECT SUM(DATEDIFF(sb_finish, sb_start)) AS days_sum
	FROM subscriptions
	WHERE sb_is_active = 'N') AS tmp_days_sum
SET books_taken = active_count / subscribers_count,
	days_to_read = days_sum / inactive_count,
	books_returned = inactive_count / subscribers_count ;
END;
$$

-- Now we have to restore normal query delimiter:
DELIMITER ;

-- Old versions of triggers deletion (convenient for debug) :
DROP TRIGGER upd_avgs_on_subscriptions_ins;
DROP TRIGGER upd_avgs_on_subscriptions_upd;
DROP TRIGGER upd_avgs_on_subscriptions_del;

-- We have to tell MySQL where the real query ends:
DELIMITER $$

-- Trigger for subscriptions insertion:
CREATE TRIGGER upd_avgs_on_subscriptions_ins
AFTER INSERT
ON subscriptions
FOR EACH ROW
BEGIN
UPDATE averages,
	(SELECT COUNT(s_id) AS subscribers_count
	FROM subscribers) AS tmp_subscribers_count,
	(SELECT COUNT(sb_id) AS active_count
	FROM subscriptions
	WHERE sb_is_active = 'Y') AS tmp_active_count,
	(SELECT COUNT(sb_id) AS inactive_count
	FROM subscriptions
	WHERE sb_is_active = 'N') AS tmp_inactive_count,
	(SELECT SUM(DATEDIFF(sb_finish, sb_start)) AS days_sum
	FROM subscriptions
	WHERE sb_is_active = 'N') AS tmp_days_sum
SET books_taken = active_count / subscribers_count,
	days_to_read = days_sum / inactive_count,
	books_returned = inactive_count / subscribers_count ;
END;
$$

-- Trigger for subscriptions update:
CREATE TRIGGER upd_avgs_on_subscriptions_upd
AFTER UPDATE
ON subscriptions
FOR EACH ROW
BEGIN
UPDATE averages,
	(SELECT COUNT(s_id) AS subscribers_count
	FROM subscribers) AS tmp_subscribers_count,
	(SELECT COUNT(sb_id) AS active_count
	FROM subscriptions
	WHERE sb_is_active = 'Y') AS tmp_active_count,
	(SELECT COUNT(sb_id) AS inactive_count
	FROM subscriptions
	WHERE sb_is_active = 'N') AS tmp_inactive_count,
	(SELECT SUM(DATEDIFF(sb_finish, sb_start)) AS days_sum
	FROM subscriptions
	WHERE sb_is_active = 'N') AS tmp_days_sum
SET books_taken = active_count / subscribers_count,
	days_to_read = days_sum / inactive_count,
	books_returned = inactive_count / subscribers_count ;
END;
$$

-- Trigger for subscriptions delete:
CREATE TRIGGER upd_avgs_on_subscriptions_del
AFTER DELETE
ON subscriptions
FOR EACH ROW
BEGIN
UPDATE averages,
	(SELECT COUNT(s_id) AS subscribers_count
	FROM subscribers) AS tmp_subscribers_count,
	(SELECT COUNT(sb_id) AS active_count
	FROM subscriptions
	WHERE sb_is_active = 'Y') AS tmp_active_count,
	(SELECT COUNT(sb_id) AS inactive_count
	FROM subscriptions
	WHERE sb_is_active = 'N') AS tmp_inactive_count,
	(SELECT SUM(DATEDIFF(sb_finish, sb_start)) AS days_sum
	FROM subscriptions
	WHERE sb_is_active = 'N') AS tmp_days_sum
SET books_taken = active_count / subscribers_count,
	days_to_read = days_sum / inactive_count,
	books_returned = inactive_count / subscribers_count ;
END;
$$

/* 02 - Using Triggers to Ensure Data Consistency */
/* 3. Modify “subscribers” table to store the number of books taken
by each subscriber (and keep that data up-to-date).*/
-- Table modification:
ALTER TABLE subscribers
ADD COLUMN s_books INT(11) NOT NULL DEFAULT 0 AFTER s_name;

-- Data initialization:
UPDATE subscribers
JOIN (SELECT sb_subscriber, COUNT(sb_id) AS s_has_books
FROM subscriptions
WHERE sb_is_active = 'Y'
GROUP BY sb_subscriber) AS prepared_data
ON s_id = sb_subscriber
SET s_books = s_has_books;

SELECT *
FROM subscribers

-- We have to tell MySQL where the real query ends:
DELIMITER $$

-- Trigger for subscriptions insertion:
CREATE TRIGGER s_has_books_on_subscriptions_ins
AFTER INSERT
ON subscriptions
FOR EACH ROW
BEGIN
IF (NEW.sb_is_active = 'Y') THEN
UPDATE subscribers
SET s_books = s_books + 1
WHERE s_id = NEW.sb_subscriber;
END IF;
END;
$$

-- Trigger for subscriptions deletior
CREATE TRIGGER s_has_books_on_subscriptions_del
AFTER DELETE
ON subscriptions
FOR EACH ROW
BEGIN
IF (OLD.sb_is_active = 'Y') THEN
UPDATE subscribers
SET s_books = s_books - 1
WHERE s_id = OLD.sb_subscriber ;
END IF;
END;
$$

-- Trigger for subscriptions update:
CREATE TRIGGER s_has_books_on_subscriptions_upd
AFTER UPDATE
ON subscriptions
FOR EACH ROW
BEGIN
	-- A) Same subscriber, Y -> N
	IF ((OLD.sb_subscriber = NEW.sb_subscriber) AND
		(OLD.sb_is_active = 'Y') AND
		(NEW.sb_is_active = 'N')) THEN
	UPDATE subscribers
	SET s_books = s_books - 1
	WHERE s_id = OLD.sb_subscriber;
	END IF;
	-- B) Same subscriber, N -> Y
	IF ((OLD.sb_subscriber = NEW.sb_subscriber) AND
		(OLD.sb_is_active = 'N') AND
		(NEW.sb_is_active = 'Y')) THEN
	UPDATE subscribers
	SET s_books = s_books + 1
	WHERE s_id = OLD.sb_subscriber;
	END IF;
    -- C) Different subscriber, Y -> Y
	IF ((OLD.sb_subscriber != NEW.sb_subscriber) AND
		(OLD.sb_is_active = 'Y') AND
		(NEW.sb_is_active = 'Y')) THEN
	UPDATE subscribers
	SET s_books = s_books - 1
	WHERE s_id = OLD.sb_subscriber;
    UPDATE subscribers
	SET s_books = s_books + 1
	WHERE s_id = NEW.sb_subscriber;
	END IF;
    -- D) Different subscriber, Y -> N
	IF ((OLD.sb_subscriber != NEW.sb_subscriber) AND
		(OLD.sb_is_active = 'Y') AND
		(NEW.sb_is_active = 'N')) THEN
	UPDATE subscribers
	SET s_books = s_books - 1
	WHERE s_id = OLD.sb_subscriber;
	END IF;
    -- E) Different subscriber, N -> Y
	IF ((OLD.sb_subscriber != NEW.sb_subscriber) AND
		(OLD.sb_is_active = 'N') AND
		(NEW.sb_is_active = 'Y')) THEN
	UPDATE subscribers
	SET s_books = s_books + 1
	WHERE s_id = NEW.sb_subscriber;
	END IF;
END;
$$

-- Now we have to restore normal query delimiter:
DELIMITER ;

/* 4. Modify “genres” table to store the number of books in each
genre (and keep that data up-to-date).*/
-- Table modification:
ALTER TABLE genres
ADD COLUMN g_books INT(11) NOT NULL DEFAULT 0 AFTER g_name ;

-- Data initialization:
UPDATE genres
	JOIN (SELECT g_id,
	COUNT(b_id) AS g_has_books
	FROM m2m_books_genres
	GROUP BY g_id) AS prepared_data
	USING (g_id)
SET g_books = g_has_books ;

SELECT *
FROM genres;

-- We have to tell MySQL where the real query ends:
DELIMITER $$

-- Trigger for books-genres association insertion:
CREATE TRIGGER `g_has_books_on_m2m_b_g_ins`
AFTER INSERT
ON `m2m_books_genres`
FOR EACH ROW
BEGIN
UPDATE `genres`
SET  `g_books` = `g_books` + 1
WHERE `g_id` = NEW.`g_id`;
END;
$$

-- Trigger for books-genres association update:
DELIMITER $$
CREATE TRIGGER `g_has_books_on_m2m_b_g_upd`
AFTER UPDATE
ON `m2m_books_genres`
FOR EACH ROW
BEGIN
UPDATE `genres`
SET  `g_books` = `g_books` - 1
WHERE `g_id` = OLD.`g_id`;
UPDATE `genres`
SET  `g_books` = `g_books` + 1
WHERE `g_id` = NEW.`g_id`;
END;
$$

-- Trigger for books-genres association deletion:
DELIMITER $$
CREATE TRIGGER `g_has_books_on_m2m_b_g_del`
AFTER DELETE
ON `m2m_books_genres`
FOR EACH ROW
BEGIN
UPDATE `genres`
SET  `g_books` = `g_books` - 1
WHERE `g_id` = OLD.`g_id`;
END;
$$

-- Trigger for books deletion:
DELIMITER $$
CREATE TRIGGER `g_has_books_on_books_del`
BEFORE DELETE
ON `books`
FOR EACH ROW
BEGIN
UPDATE `genres`
SET  `g_books` = `g_books` - 1
WHERE `g_id` IN (SELECT `g_id`
				FROM `m2m_books_genres`
                WHERE `b_id` = OLD.`b_id`);
END;
$$

-- Now we have to restore normal query delimiter:
DELIMITER ;

/* 03 - Using Triggers to Control Data Modification*/
/* 5. Create a trigger to prevent the following situations with subscriptions:
- subscription start date is in the future;
- subscription end date is in the past (for INSERT operations
only);
- subscription end date is less than subscription start date.*/
DELIMITER $$
CREATE TRIGGER subscriptions_control_ins
AFTER INSERT
ON subscriptions
FOR EACH ROW
BEGIN
-- Prevention of insertion of a subscription with the start date is in the future:
IF NEW.sb_start > CURDATE()
THEN
SET @msg = CONCAT('Date ', NEW.sb_start, ' for subscription ', NEW.sb_id, ' activation is in the future.');
SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1001;
END IF;
-- Prevention of insertion of a subscription with the end date is in the past:
IF NEW.`sb_finish` < CURDATE()
THEN
SET @msg = CONCAT('Date ', NEW.sb_finish, ' for subscription ', NEW.sb_id, ' deactivation is in the past.');
SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1002;
END IF;
-- Prevention of insertion of a subscription with the end date less than the start date:
IF NEW.sb_finish < NEW.sb_start
THEN
SET @msg = CONCAT('Date ', NEW.sb_finish, ' for subscription ', NEW.sb_id, 
' deactivation is less than the date for its activation (', NEW.sb_start, ').');
SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1003;
END IF;
END; 
$$ 
/*This is how to block an operation from within a trigger in MySQL.*/

DELIMITER $$
CREATE TRIGGER subscriptions_control_upd  /*We don't need a DELETE-trigger as it’s impossible to violate any mentioned rules during DELETE operation*/
AFTER UPDATE  
ON subscriptions
FOR EACH ROW 
BEGIN
-- Prevention of appearance of a subscription with the start date is in the future:
IF NEW.sb_start > CURDATE ()
THEN
SET @msg = CONCAT('Date ', NEW.sb_start, ' for subscription ',
NEW.sb_id, ' activation is in the future.') ;
SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1001;
END IF;
-- Prevention of appearance of a subscription with the end date less than the start date:
IF NEW.sb_finish < NEW.sb_start
THEN
SET @msg = CONCAT('Date ', NEW.sb_finish, ' for subscription ',
NEW.sb_id, ' deactivation is less than the date for its activation (',
NEW.sb_start, ').');
SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1003;
END IF;
END
$$

/* 6. Create a trigger to prevent creation of a new subscription for a
subscriber already having 10 (and more) books taken.*/
DELIMITER $$
CREATE TRIGGER sbs_cntr1_10_books_ins_OK
BEFORE INSERT
ON subscriptions
FOR EACH ROW
BEGIN
SET @msg = IFNULL( (SELECT CONCAT('Subscriber ', s_name,
						' (id=', sb_subscriber, ') already has ',
						sb_books, ' books out of 10 allowed.')
						AS message
				FROM (SELECT sb_subscriber,
						COUNT (sb_book) AS sb_books
					FROM subscriptions
					WHERE sb_is_active = 'Y'
					AND sb_subscriber = NEW.sb_subscriber
					GROUP BY sb_subscriber
					HAVING sb_books >= 10) AS prepared_data
				JOIN subscribers ON sb_subscriber = s_id),
			'');
IF (LENGTH(@msg) > 0)
THEN
SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1001;
END IF;
END ;
$$

DELIMITER $$
CREATE TRIGGER sbs_cntr1_10_books_upd_OK
BEFORE UPDATE
ON subscriptions
FOR EACH ROW
BEGIN
SET @msg = IFNULL( (SELECT CONCAT('Subscriber ', s_name,
						' (id=', sb_subscriber, ') already has ',
						sb_books, ' books out of 10 allowed.')
						AS message
				FROM (SELECT sb_subscriber,
						COUNT (sb_book) AS sb_books
					FROM subscriptions
					WHERE sb_is_active = 'Y'
					AND sb_subscriber = NEW.sb_subscriber
					GROUP BY sb_subscriber
					HAVING sb_books >= 10) AS prepared_data
				JOIN subscribers ON sb_subscriber = s_id),
			'');
IF (LENGTH(@msg) > 0)
THEN
SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1001;
END IF;
END ;
$$

/* 7. Create a trigger to prevent modifying a subscription from
inactive state back to active (i.e. from modifying “sb_is_active”
field value from “N” to “Y”).*/
DELIMITER $$
CREATE TRIGGER sbs_cntrl_is_active
BEFORE UPDATE
ON subscriptions
FOR EACH ROW
BEGIN
IF ((OLD.sb_is_active = 'N') AND (NEW.sb_is_active = 'Y'))
THEN
SET @msg = CONCAT('It is prohibited to activate previously
deactivated subscriptions (rule violated
for subscription with id ', NEW.sb_id, ').');
SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1001;
END IF;
END ;
$$

/* 04 - Using Triggers to Control Data Format and Values */
/* 8. Create a trigger to only allow registration of subscribers with a
dot and at least two words in their names.*/
DELIMITER $$
CREATE TRIGGER sbsrs_cntrl_name_ins
BEFORE INSERT
ON subscribers
FOR EACH ROW
BEGIN
IF ((NEW.s_name REGEXP '^[a-zA-Zа-яА-ЯёЁ\'-]+([^[a-zA-Zа-яА-ЯёЁ\'-]+[a-zA-Zа-яА-ЯёЁ\'.-]+){1,}$') = 0)
OR (LOCATE('.', NEW.s_name) = 0)
THEN
SET @msg = CONCAT('Subscribers name should contain at
least two words and one point, but the following
name violates this rule: ', NEW.s_name) ;
SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1001;
END IF;
END ;
$$

DELIMITER $$
CREATE TRIGGER sbsrs_cntrl_name_upd
BEFORE UPDATE
ON subscribers
FOR EACH ROW
BEGIN
IF ((NEW.s_name REGEXP '^[a-zA-Zа-яА-ЯёЁ\'-]+([^[a-zA-Zа-яА-ЯёЁ\'-]+[a-zA-Zа-яА-ЯёЁ\'.-]+){1,}$') = 0)
OR (LOCATE('.', NEW.s_name) = 0)
THEN
SET @msg = CONCAT('Subscribers name should contain at
least two words and one point, but the following
name violates this rule: ', NEW.s_name) ;
SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1001;
END IF;
END ;
$$

/* 9. Create a trigger to only allow registration of books issued no
more than 100 years ago.*/
DELIMITER $$
CREATE TRIGGER books_cntrl_year_ins
BEFORE INSERT
ON books
FOR EACH ROW
BEGIN
IF ((YEAR(CURDATE()) - NEW.b_year) > 100)
THEN
SET @msg = CONCAT('The following issuing year is more than
100 years in the past: ', NEW.b_year);
SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1001;
END IF;
END ;
$$

DELIMITER $$
CREATE TRIGGER books_cntrl_year_upd
BEFORE UPDATE
ON books
FOR EACH ROW
BEGIN
IF ((YEAR(CURDATE()) - NEW.b_year) > 100)
THEN
SET @msg = CONCAT('The following issuing year is more than 100 years in the past:', NEW.b_year) ;
SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1001;
END IF;
END;
$$

/* 05 - Using Triggers to Correct Data On-the-Fly*/
/* 10. Create a trigger to check if there is a dot at the end of
subscriber’s name and to add a such dot if there is no one.*/
DELIMITER $$
CREATE TRIGGER sbsrs_name_lp_ins
BEFORE INSERT
ON subscribers
FOR EACH ROW
BEGIN
IF (SUBSTRING(NEW.s_name, -1) <> '.')
THEN
SET @new_value = CONCAT(NEW.s_name, '.');
SET @msg = CONCAT('Value [', NEW.s_name, '] was automatically
changed to [', @new_value ,']');
SET NEW.s_name = @new_value;
SIGNAL SQLSTATE '01000' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1000;
END IF;
END ;
$$

DELIMITER $$
CREATE TRIGGER sbsrs_name_lp_upd
BEFORE UPDATE
ON subscribers
FOR EACH ROW
BEGIN
IF (SUBSTRING(NEW.s_name, -1) <> '.')
THEN
SET @new_value = CONCAT(NEW.s_name, '.');
SET @msg = CONCAT('Value [', NEW.s_name, '] was automatically
changed to [', @new_value ,']');
SET NEW.s_name = @new_value;
SIGNAL SQLSTATE '01000' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1000;
END IF;
END ;
$$

/* 11. Create a trigger to change the subscription end date to “current
date + two months” if the given end date is in the past or is less than the start date.*/
DELIMITER $$
CREATE TRIGGER sbscs_date_tm_ins
BEFORE INSERT
ON subscriptions
FOR EACH ROW
BEGIN
IF (NEW. sb_finish < NEW.sb_start) OR (NEW.sb_finish < CURDATE() )
THEN
SET @new_value = DATE_ADD(CURDATE(), INTERVAL 2 MONTH) ;
SET @msg = CONCAT('Value [', NEW.sb_finish, '] was automatically
changed to [', @new_value ,']');
SET NEW. sb_finish = @new_value;
SIGNAL SQLSTATE '01000' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1000;
END IF;
END ;
$$

DELIMITER $$
CREATE TRIGGER sbscs_date_tm_upd
BEFORE UPDATE
ON subscriptions
FOR EACH ROW
BEGIN
IF (NEW. sb_finish < NEW.sb_start) OR (NEW.sb_finish < CURDATE() )
THEN
SET @new_value = DATE_ADD(CURDATE(), INTERVAL 2 MONTH) ;
SET @msg = CONCAT('Value [', NEW.sb_finish, '] was automatically
changed to [', @new_value ,']');
SET NEW. sb_finish = @new_value;
SIGNAL SQLSTATE '01000' SET MESSAGE_TEXT = @msg, MYSQL_ERRNO = 1000;
END IF;
END ;
$$