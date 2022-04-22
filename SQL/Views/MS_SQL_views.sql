/* 01 - 01 - Using Non-Caching Views to Select Data*/
/* 1. Create a view to simplify access to the data produced by the
following queries (see Task 4 in “JOINs with MIN, MAX, AVG,
range”)..*/
CREATE VIEW first_book AS /* Just add this line to the beginning of the query*/
WITH step_1
	AS (SELECT sb_subscriber, MIN(sb_start) AS min_sb_start
		FROM subscriptions
		GROUP BY sb_subscriber),
	step_2
	AS (SELECT subscriptions.sb_subscriber, MIN(sb_id) AS min_sb_id
		FROM subscriptions
		JOIN step_1 ON subscriptions.sb_subscriber = step_1.sb_subscriber
		AND subscriptions.sb_start = step_1.min_sb_start
		GROUP BY subscriptions.sb_subscriber, min_sb_start),
	step_3
	AS (SELECT subscriptions.sb_subscriber, sb_book
		FROM subscriptions
		JOIN step_2 ON subscriptions.sb_id = step_2.min_sb_id)
SELECT s_id, s_name, b_name
FROM step_3
JOIN subscribers ON sb_subscriber = s_id
JOIN books ON sb_book = b_id;
/* The result would be achiveable via query:*/
SELECT *
FROM first_book;

/* 2. Create a view to show authors along with their books quantity
taking into account only authors with two or more books.*/
CREATE VIEW [authors_with_more_than_one_book] AS
SELECT authors.a_id, authors.a_name, COUNT(b_id) AS books_in_library
FROM authors
JOIN m2m_books_authors ON  m2m_books_authors.a_id = authors.a_id
GROUP BY authors.a_id, authors.a_name
HAVING COUNT(b_id) > 1;

SELECT *
FROM authors_with_more_than_one_book;


/* 02 - Using Caching Views and Tables to Select Data*/
/* 3. Create a view to speed up the retrieval of the following data:
- total books count;
- taken books count;
- available books count.*/
/* Aggregation table creation (MS SQL supports materialized views, but there are a lot of limitations, so we have to use a table):*/
CREATE TABLE books_statistics
(
total INTEGER NOT NULL,
given INTEGER NOT NULL,
rest INTEGER NOT NULL
);

-- Aggregation table truncation:
TRUNCATE TABLE books_statistics;

-- Aggregation table data initialization:
INSERT INTO books_statistics
	(total, 
	given,
	rest)
SELECT ISNULL(total, 0) AS total,
	ISNULL(given, 0) AS given,
	ISNULL(total - given, 0) AS rest
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
GO

-- Trigger for books insertion:
CREATE TRIGGER upd_bks_sts_on_books_ins
ON books
AFTER INSERT
AS 
	UPDATE books_statistics SET
	total = total + (SELECT SUM(b_quantity)
					FROM inserted); /* MS SQL does not allow to modify a field
									value and immediately use the new value
									in a single query, so we have to execute
									two separate queries here.*/
	UPDATE books_statistics SET
	rest = total - given;
GO

-- Trigger for books deletion:
CREATE TRIGGER upd_bks_sts_on_books_del
ON books
AFTER DELETE
AS 
	UPDATE books_statistics SET
	total = total - (SELECT SUM(b_quantity)
					FROM deleted),
	given = given - (SELECT COUNT(sb_book)
					FROM subscriptions
					WHERE sb_book IN (SELECT b_id
									FROM deleted)
						AND sb_is_active = 'Y');
	UPDATE books_statistics SET
	rest = total - given;
GO

-- Trigger for books quantity update:
CREATE TRIGGER upd_bks_sts_on_books_upd
ON books
AFTER UPDATE
AS 
	UPDATE books_statistics SET
	total = total - (SELECT SUM(b_quantity)
					FROM deleted) + (SELECT SUM(b_quantity)
									FROM inserted);
	UPDATE books_statistics SET
	rest = total - given;
GO

-- Old versions of triggers deletion (convenient for debug) :
DROP TRIGGER upd_bks_sts_on_subscriptions_ins;
DROP TRIGGER upd_bks_sts_on_subscriptions_del;
DROP TRIGGER upd_bks_sts_on_subscriptions_upd;
GO

-- Trigger for subscriptions insertion:
CREATE TRIGGER upd_bks_sts_on_subscriptions_ins
ON subscriptions
AFTER INSERT
AS
DECLARE @delta INT = (SELECT COUNT(*)
					FROM inserted
					WHERE sb_is_active = 'Y');
UPDATE books_statistics SET
	rest = rest - @delta,
	given = given + @delta;
GO

-- Trigger for subscriptions deletion:
CREATE TRIGGER upd_bks_sts_on_subscriptions_del
ON subscriptions
AFTER DELETE
AS DECLARE @delta INT = (SELECT COUNT(*)
					FROM deleted
					WHERE sb_is_active = 'Y');
UPDATE books_statistics SET
	rest = rest + @delta,
	given = given - @delta;
GO

-- Trigger for subscriptions modification:
CREATE TRIGGER [upd_bks_sts_on_subscriptions_upd]
ON [subscriptions]
AFTER UPDATE
AS
DECLARE @taken INT = (
SELECT COUNT(*)
FROM [inserted]
JOIN [deleted]
ON [inserted].[sb_id] = [deleted].[sb_id]
WHERE [inserted].[sb_is_active] = 'Y'
AND [deleted].[sb_is_active] = 'N');

DECLARE @returned INT = (
SELECT COUNT (*)
FROM [inserted]
JOIN [deleted]
ON [inserted].[sb_id] = [deleted].[sb_id]
WHERE [inserted].[sb_is_active] = 'N'
AND [deleted] .[sb_is_active] = 'Y');

DECLARE @delta INT = @taken - @returned;

UPDATE [books_statistics] SET
[rest] = [rest] - @delta,
[given] = [given] + @delta;
GO

SELECT *
FROM books_statistics;

SELECT *
FROM subscriptions;

/* 4. Create a view to speed up the retrieval of “subscriptions” table
data in “human-readable form” (i.e. with books names,
subscribers names, etc.....)*/
-- Old version of view deletion (convenient for debug) :
DROP VIEW [subscriptions_ready];

-- View creation:
CREATE VIEW [subscriptions_ready]
WITH SCHEMABINDING
AS
SELECT [sb_id],
[s_name] AS [sb_subscriber],
[b_name] AS [sb_book],
[sb_start],
[sb_finish],
[sb_is_active]
FROM [dbo].[books]
JOIN [dbo].[subscriptions] ON [b_id] = [sb_book]
JOIN [dbo].[subscribers] ON [sb_subscriber] = [s_id]; 

-- Unique clustered index creation (this operation enables
-- automatic view update and makes the view a materialized one):
CREATE UNIQUE CLUSTERED INDEX [idx_subscriptions_ready]
ON [subscriptions_ready] ([sb_id]);

SELECT *
FROM [subscriptions_ready];

/* 03 - Using Views to Obscure Database Structures and Data Values */
/* 5. Create a view on "subscriptions" table to hide the information about subscribers. */
CREATE VIEW subscriptions_anonymous
WITH SCHEMABINDING /* the DBMS will check underlying objects existence and availability*/
AS
	SELECT sb_id,
		sb_book,
		sb_start,
		sb_finish,
		sb_is_active
    FROM dbo.subscriptions; /* This is SCHEMABINDING to work*/

SELECT *
FROM subscriptions_anonymous;

/* 6. Create a view on "subscriptions" table to present all dates in Unixtime format. */
CREATE VIEW subscriptions_unixtime
WITH SCHEMABINDING
AS
	SELECT sb_id,
		sb_subscriber,
		sb_book,
		DATEDIFF(SECOND, CAST(N'1970-01-01' AS DATE), sb_start) AS sb_start,
		DATEDIFF(SECOND, CAST(N'1970-01-01' AS DATE), sb_finish) AS sb_finish,
		sb_is_active
    FROM dbo.subscriptions;

SELECT *
FROM subscriptions_unixtime;

/* 7. Create a view on "subscriptions" table to present all dates in "YYYY-MM-DD DW" format, where "DW" is a full day of week name (e.g., "Sunday", "Monday", etc.)*/
CREATE VIEW subscriptions_data_wd
WITH SCHEMABINDING
AS
	SELECT sb_id,
		sb_subscriber,
		sb_book,
		CONCAT(sb_start, ' - ',  DATENAME(DW, sb_start)) AS sb_start_dw,
		CONCAT(sb_finish, ' - ', DATENAME(DW, sb_finish)) AS sb_finish_dw,
		sb_is_active
    FROM dbo.subscriptions;

SELECT *
FROM subscriptions_data_wd;

/* 04 - Using Updatable Views to Modify Data */
/* 8. Create a view on “subscribers” table to present all subscribers’
names in upper case while allowing to modify “subscribers”
table via operations with the view.*/
-- View creation (allows deletion only):
CREATE VIEW subscribers_upper_case
WITH SCHEMABINDING
AS
	SELECT s_id, UPPER(s_name) AS s_name
    FROM dbo.subscribers;

SELECT *
FROM subscribers_upper_case;

-- INSERT trigger creation:
CREATE TRIGGER [subscribers_upper_case_ins]
ON [subscribers_upper_case]
INSTEAD OF INSERT
AS
	SET IDENTITY_INSERT [subscribers] ON; 
	INSERT INTO subscribers
				(s_id, s_name)
	SELECT ( CASE
			WHEN [s_id] IS NULL /*If the primary key value is not explicitly passed into the query, we have to calculate it.*/
				OR [s_id] = 0 THEN IDENT_CURRENT('subscribers')
								+ IDENT_INCR('subscribers')
								+ ROW_NUMBER() OVER (ORDER BY (SELECT 1) )
								- 1
			ELSE [s_id]
			END ) AS [s_id], 
			[s_name]
	FROM [inserted] ;
	SET IDENTITY_INSERT [subscribers] OFF;
GO

-- UPDATE trigger creation:
CREATE TRIGGER [subscribers_upper_case_upd]
ON [subscribers_upper_case]
INSTEAD OF UPDATE
AS
	IF UPDATE ([s_id])
	BEGIN
		RAISERROR ('UPDATE of Primary Key through  
					[subscribers_upper_case_upd] 
					view is prohibited.', 16, 1); 
		ROLLBACK; /*If the primary key is modified, we can not match old and new values, so we rollback the whole operation*/
	END
	ELSE
		UPDATE [subscribers]
		SET [subscribers].[s_name] = [inserted].[s_name]
		FROM [subscribers]
		JOIN [inserted]
		ON [subscribers].[s_id] = [inserted].[s_id];
GO

/* 9. Create a view on “subscriptions” table to present subscription
start and finish dates as a single string while allowing to modify
“subscriptions” table via operations with the view.*/
-- View creation (allows deletion only):
CREATE VIEW subscriptions_wcd
WITH SCHEMABINDING
AS
	SELECT sb_id,
			sb_subscriber,
            sb_book,
            CONCAT(sb_start, ' - ', sb_finish) AS sb_dates,
            sb_is_active
	FROM dbo.subscriptions

SELECT *
FROM subscriptions_wcd;

-- INSERT trigger creation:
CREATE TRIGGER [subscriptions_wcd_ins]
ON [subscriptions_wcd]
INSTEAD OF INSERT
AS
	SET IDENTITY_INSERT [subscriptions] ON;
	INSERT INTO [subscriptions]
				([sb_id] ,
				[sb_subscriber] ,
				[sb_book],
				[sb_start],
				[sb_finish],
				[sb_is_active])
	SELECT ( CASE
				WHEN [sb_id] IS NULL /*If the primary key value is not explicitly passed into the query, we have to calculate it.*/
				OR [sb_id] = 0 THEN IDENT_CURRENT('subscriptions')
									+ IDENT_INCR('subscriptions')
									+ ROW_NUMBER() OVER (ORDER BY (SELECT 1))
									-1
				ELSE [sb_id]
			END ) AS [sb_id],
			[sb_subscriber] ,
			[sb_book],
			SUBSTRING([sb_dates], 1, (CHARINDEX(' ', [sb_dates]) - 1))	AS [sb_start],
			SUBSTRING ([sb_dates], (CHARINDEX(' ', [sb_dates]) + 3), 
									DATALENGTH ([sb_dates]) -
									(CHARINDEX(' ', [sb_dates]) + 2)) AS [sb_finish] , /* We have to use such a strange approach to extract two dates from a single string.*/
			[sb_is_active]
FROM [inserted] ;
SET IDENTITY_INSERT [subscriptions] OFF;
GO

-- UPDATE trigger creation:
CREATE TRIGGER [subscriptions_wcd_upd]
ON [subscriptions_wcd]
INSTEAD OF UPDATE
AS
	IF UPDATE ([sb_id]) /*If the primary key is modified, we can not match old and new values, so we rollback the whole operation.*/
		BEGIN
			RAISERROR ('UPDATE of Primary Key through [subscriptions_wcd_upd] view is prohibited.', 16, 1);
			ROLLBACK ;
		END
	ELSE
		UPDATE [subscriptions]
		SET [subscriptions].[sb_subscriber] = [inserted].[sb_subscriber],
			[subscriptions].[sb_book] = [inserted].[sb_book],
			[subscriptions].[sb_start] = SUBSTRING([sb_dates], 1, (CHARINDEX(' ', [sb_dates]) - 1)),
			[subscriptions].[sb_finish] = SUBSTRING ([sb_dates], (CHARINDEX(' ', [sb_dates]) +3),
										DATALENGTH ([sb_dates]) - (CHARINDEX(' ', [sb_dates]) +2)),
										/*We have to use such a strange approach to extract two dates from a single string.*/
			[subscriptions].[sb_is_active] = [inserted].[sb_is_active]
		FROM [subscriptions]
		JOIN [inserted] ON [subscriptions].[sb_id] = [inserted].[sb_id];
GO

/* 05 - Using Triggers on Views to Modify Data*/
/* 10. Create a view on “subscribers” table to present all the data in
“human-readable” form (i.e. with explicit names/titles instead
of ids) while allowing to modify “subscribers” table via
operations with the view.*/
-- View creation:
CREATE VIEW subscriptions_with_text
WITH SCHEMABINDING
AS
	SELECT sb_id,
		s_name AS sb_subscriber,
		b_name AS sb_book,
        sb_start,
        sb_finish,
        sb_is_active
	FROM dbo.subscriptions
	JOIN dbo.subscribers ON sb_subscriber = s_id
	JOIN dbo.books ON sb_book = b_id;

SELECT *
FROM subscriptions_with_text;

-- INSERT trigger creation:
CREATE TRIGGER [subscriptions_with_text_ins]
ON [subscriptions_with_text]
INSTEAD OF INSERT
AS
	IF EXISTS (SELECT 1
	FROM [inserted]
	WHERE PATINDEX('%[^0-9]%', [sb_subscriber]) > 0
	OR PATINDEX('%[^0-9]%', [sb_book]) > 0)
	BEGIN 
		RAISERROR ('Use digital identifiers for [sb_subscriber]
		and [sb_book]. Do not use subscribers'' names
		or books'' titles', 16, 1); /* As names or titles not unique, we allow only ids usage here*/
		ROLLBACK;
	END
	ELSE
	BEGIN
	SET IDENTITY_INSERT [subscriptions] ON;
	INSERT INTO [subscriptions]
				([sb_id],
				[sb_subscriber] ,
				[sb_book] ,
				[sb_start],
				[sb_finish] ,
				[sb_is_active])
	SELECT ( CASE
			WHEN [sb_id] IS NULL /*If the primary key value is not explicitly passed into the query, we have to calculate it.*/
			OR [sb_id] = 0 THEN IDENT_CURRENT('subscriptions')
			+ IDENT_INCR('subscriptions')
			+ ROW_NUMBER() OVER (ORDER BY (SELECT 1))
			-1 
		ELSE [sb_id]
	END ) AS [sb_id],
	[sb_subscriber] ,
	[sb_book] ,
	[sb_start],
	[sb_finish] ,
	[sb_is_active]
	FROM [inserted] ;
	SET IDENTITY_INSERT [subscriptions] OFF;
	END
GO

-- UPDATE trigger creation
CREATE TRIGGER [subscriptions_with_text_upd]
ON [subscriptions_with_text]
INSTEAD OF UPDATE
AS
IF EXISTS (SELECT 1
FROM [inserted]
WHERE ( UPDATE ([sb_subscriber]) AND PATINDEX('%[^0-9]%', [sb_subscriber]) > 0)
OR (UPDATE ([sb_book]) AND PATINDEX ('%[^0-9]%', [sb_book]) > 0))
BEGIN
RAISERROR ('Use digital identifiers for [sb_subscriber]
		and [sb_book]. Do not use subscribers'' names
		or books'' titles', 16, 1);
ROLLBACK;
END
ELSE
BEGIN
IF UPDATE ([sb_id])
BEGIN
	RAISERROR ('UPDATE of Primary Key through [subscriptions_with_text] view is prohibited.', 16, 1);
	ROLLBACK;
END
ELSE
BEGIN
UPDATE [subscriptions]
SET [subscriptions].[sb_subscriber] =
	CASE
	WHEN (PATINDEX('%[^0-9]%', [inserted].[sb_subscriber]) = 0)
	THEN [inserted].[sb_subscriber]
	ELSE [subscriptions].[sb_subscriber]
	END,
[subscriptions].[sb_book] =
CASE
WHEN (PATINDEX('%[^0-9]%', [inserted].[sb_book]) = 0)
THEN [inserted].[sb_book]
ELSE [subscriptions].[sb_book]
END,
[subscriptions].[sb_start] = [inserted].[sb_start],
[subscriptions].[sb_finish] = [inserted].[sb_finish],
[subscriptions].[sb_is_active] = [inserted].[sb_is_active]
FROM [subscriptions]
JOIN [inserted] ON [subscriptions].[sb_id] = [inserted].[sb_id];
END
END
GO

-- DELETE trigger creation:
/* 1) MS SQL populates [deleted] table before trigger activation, so we can not
handle string names/titles (this problem has no solution).
2) We can not search records for deletion based on ids (as the view selects
names/titles), and we can not use names/titles as they are not unique (this
problem has some weird solution).*/
CREATE TRIGGER [subscriptions_with_text_del]
ON [subscriptions_with_text]
INSTEAD OF DELETE
AS
DELETE FROM [subscriptions]
WHERE [sb_id] IN (SELECT [sb_id]
				FROM [deleted] ) ;
GO

-- DELETE trigger creation:
CREATE TRIGGER [subscriptions_with_text_del]
ON [subscriptions_with_text]
INSTEAD OF DELETE
AS
-- Here we try to find out if "sb subscriber" and/or "sb book" fields are used in DELETE query:
SET NOCOUNT ON;
DECLARE @ExecStr VARCHAR(50), @Qry NVARCHAR(255) ;
CREATE TABLE #inputbuffer
(
[EventType] NVARCHAR(30) ,
[Parameters] INT,
[EventInfo] NVARCHAR(255)
);

SET @ExecStr = 'DBCC INPUTBUFFER(' + STR(@@SPID) + ')';
INSERT INTO #inputbuffer EXEC (@ExecStr) ;
SET @Qry - LOWER( (SELECT [EventInfo] FROM #inputbuffer) ) ;
-- For debug purpose you may uncomment the next string and make sure in contains the query that initiated the trigger activation:
-- PRINT (@Qry) ;
IF ((CHARINDEX ('sb_subscriber', @Qry) > 0)
OR (CHARINDEX ('sb_book', @Qry) > 0))
BEGIN
RAISERROR ('Deletion from [subscriptions with text] view
using [sb_subscriber] and/or [sb_book]
is prohibited.', 16, 1);
ROLLBACK ;
END
SET NOCOUNT OFF; /*This is the attempt to deal with that problem: “2) We
					can not search records for deletion based on ids (as
					the view selects names/titles), and we can not use
					names/titles as they are not unique.”*/


-- Here we perform the deletion itself:
DELETE FROM [subscriptions]
WHERE [sb_id] IN (SELECT [sb_id]
				FROM [deleted]) ;
GO

/* 11. Create a view to select books’ titles along with books’ genres
while allowing to add new genres via operations with the view.*/
-- View creation:
CREATE VIEW [books_with_genres]
AS
WITH [prepared_data]
AS (SELECT [books].[b_id],
			[b_name],
			[g_name]
	FROM [books]
	JOIN [m2m_books_genres] ON [books].[b_id] = [m2m_books_genres].[b_id]
	JOIN [genres] ON [m2m_books_genres].[g_id] = [genres].[g_id]
	)
SELECT [outer].[b_id],
		[outer].[b_name] , /* May use STRING_AGG*/
		STUFF ((SELECT DISTINCT ',' + [inner].[g_name]
				FROM [prepared_data] AS [inner]
				WHERE [outer].[b_id] = [inner].[b_id]
				ORDER BY ',' + [inner].[g_name]
				FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)') ,
				1,1, '')
		AS [genres]
FROM [prepared_data] AS [outer]
GROUP BY [outer].[b_id],
		[outer].[b_name];

SELECT *
FROM [books_with_genres];

-- INSERT trigger creation:(That’s all. We can not pass genre id, but we still can add new genres that easy)
CREATE TRIGGER [books_with_genres_ins]
ON [books_with_genres]
INSTEAD OF INSERT
AS
	INSERT INTO [genres]
				([g_name])
	SELECT [genres]
	FROM [inserted] ;
GO

 

.


 

 


