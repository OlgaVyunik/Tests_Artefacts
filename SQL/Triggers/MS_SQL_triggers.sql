/* 01 - Using Triggers to Update Caching Tables and Fields*/
/* 1. Modify “subscribers” table to store the last visit date for each
subscriber (and keep that data up-to-date).*/
-- Table modification:
ALTER TABLE subscribers
ADD s_last_visit DATE NULL DEFAULT NULL;

-- Data initialization:
UPDATE subscribers
SET s_last_visit = last_visit
FROM subscribers
LEFT JOIN (SELECT sb_subscriber,
				MAX(sb_start) AS last_visit
			FROM subscriptions
			GROUP BY sb_subscriber) AS prepared_data
		ON s_id = sb_subscriber;

SELECT *
FROM subscribers;

-- Trigger for all operations with subscriptions:
CREATE TRIGGER last_visit_on_subscriptions_ins_upd_del
ON subscriptions
AFTER INSERT, UPDATE, DELETE
AS 
UPDATE subscribers
SET s_last_visit = last_visit
FROM subscribers
LEFT JOIN (SELECT sb_subscriber,
				MAX(sb_start) AS last_visit
			FROM subscriptions
			GROUP BY sb_subscriber) AS prepared_data
		ON s_id = sb_subscriber;
/* MS SQL does not support row-level triggers, so this is the most simple
(yet not so efficient as with MySQL approach) way to solve this task.*/

/* 2. Create “averages” table to store the following up-to-date information:
- average books count for “taken by a subscriber”;
- average days count for “a subscriber keeps a book”;
- average books count for “returned by a subscriber”.*/
-- Table creation:
CREATE TABLE [averages]
(
[books_taken] DOUBLE PRECISION NOT NULL,
[days_to_read] DOUBLE PRECISION NOT NULL,
[books_returned] DOUBLE PRECISION NOT NULL
)

-- Table truncation:
TRUNCATE TABLE [averages] ;

-- Data initialization:
INSERT INTO [averages]
	([books_taken] ,
	[days_to_read],
	[books_returned])
SELECT ( [active_count] / [subscribers_count] ) AS [books_taken],
	( [days_sum] / [inactive_count] ) AS [days_to_read],
	( [inactive_count] / [subscribers_count] ) AS [books_returned]
FROM (SELECT CAST(COUNT([s_id]) AS DOUBLE PRECISION) AS [subscribers_count]
	FROM [subscribers]) AS [tmp_subscribers_count] ,
	(SELECT CAST(COUNT([sb_id]) AS DOUBLE PRECISION) AS [active_count]
	FROM [subscriptions]
	WHERE [sb_is_active] = 'Y') AS [tmp_active_count],
	(SELECT CAST (COUNT([sb_id]) AS DOUBLE PRECISION) AS [inactive_count]
	FROM [subscriptions]
	WHERE [sb_is_active] = 'N') AS [tmp_inactive_count],
	(SELECT CAST(SUM(DATEDIFF (day, [sb_start], [sb_finish])) AS DOUBLE PRECISION) AS [days_sum]
	FROM [subscriptions]
	WHERE [sb_is_active] = 'N') AS [tmp_days_sum] ;

SELECT *
FROM [averages]

-- Trigger for subscribers insertion and deletion:
CREATE TRIGGER upd_avgs_on_subscribers_ins_del
ON subscribers
AFTER INSERT, DELETE
AS 
UPDATE [averages]
SET [books_taken] = [active_count] / [subscribers_count],
	[days_to_read] = [days_sum] / [inactive_count],
	[books_returned] = [inactive_count] / [subscribers_count]
FROM (SELECT CAST(COUNT([s_id]) AS DOUBLE PRECISION) AS [subscribers_count]
	FROM [subscribers]) AS [tmp_subscribers_count] ,
	(SELECT CAST(COUNT([sb_id]) AS DOUBLE PRECISION) AS [active_count]
	FROM [subscriptions]
	WHERE [sb_is_active] = 'Y') AS [tmp_active_count],
	(SELECT CAST (COUNT([sb_id]) AS DOUBLE PRECISION) AS [inactive_count]
	FROM [subscriptions]
	WHERE [sb_is_active] = 'N') AS [tmp_inactive_count],
	(SELECT CAST(SUM(DATEDIFF (day, [sb_start], [sb_finish])) AS DOUBLE PRECISION) AS [days_sum]
	FROM [subscriptions]
	WHERE [sb_is_active] = 'N') AS [tmp_days_sum] ;

-- Trigger for all operations with subscriptions:
CREATE TRIGGER upd_avgs_on_subscriptions_ins_upd_del
ON subscriptions
AFTER INSERT, UPDATE, DELETE
AS 
UPDATE [averages]
SET [books_taken] = [active_count] / [subscribers_count],
	[days_to_read] = [days_sum] / [inactive_count],
	[books_returned] = [inactive_count] / [subscribers_count]
FROM (SELECT CAST(COUNT([s_id]) AS DOUBLE PRECISION) AS [subscribers_count]
	FROM [subscribers]) AS [tmp_subscribers_count] ,
	(SELECT CAST(COUNT([sb_id]) AS DOUBLE PRECISION) AS [active_count]
	FROM [subscriptions]
	WHERE [sb_is_active] = 'Y') AS [tmp_active_count],
	(SELECT CAST (COUNT([sb_id]) AS DOUBLE PRECISION) AS [inactive_count]
	FROM [subscriptions]
	WHERE [sb_is_active] = 'N') AS [tmp_inactive_count],
	(SELECT CAST(SUM(DATEDIFF (day, [sb_start], [sb_finish])) AS DOUBLE PRECISION) AS [days_sum]
	FROM [subscriptions]
	WHERE [sb_is_active] = 'N') AS [tmp_days_sum] ;

/* 02 - Using Triggers to Ensure Data Consistency */
/* 3. Modify “subscribers” table to store the number of books taken
by each subscriber (and keep that data up-to-date).*/
-- Table modification:
ALTER TABLE [subscribers]
ADD [s_books] INT NOT NULL DEFAULT 0;

-- Data initialization:
UPDATE [subscribers]
SET [s_books] = [s_has_books]
FROM [subscribers]
JOIN (SELECT [sb_subscriber] ,
COUNT ([sb_id]) AS [s_has_books]
FROM [subscriptions]
WHERE [sb_is_active] = 'Y'
GROUP BY [sb_subscriber]) AS [prepared_data]
ON [s_id] = [sb_subscriber] ;

SELECT *
FROM subscribers

-- Trigger for subscriptions insertion:
CREATE TRIGGER [s_has_books_on_subscriptions_ins]
ON [subscriptions]
AFTER INSERT
AS
UPDATE [subscribers]
SET [s_books] = [s_books] + [s_new_books]
FROM [subscribers]
	JOIN (SELECT [sb_subscriber] ,
		COUNT([sb_id]) AS [s_new_books]
	FROM [inserted]
	WHERE [sb_is_active] = 'Y'
	GROUP BY [sb_subscriber]) AS [prepared_data]
	ON [s_id] = [sb_subscriber] ;
GO

-- Trigger for subscriptions deletion:
CREATE TRIGGER [s_has_books_on_subscriptions_del]
ON [subscriptions]
AFTER DELETE
AS
UPDATE [subscribers]
SET [s_books] = [s_books] - [s_old_books]
FROM [subscribers]
	JOIN (SELECT [sb_subscriber],
		COUNT ([sb_id]) AS [s_old_books]
	FROM [deleted]
	WHERE [sb_is_active] = 'Y'
	GROUP BY [sb_subscriber]) AS [prepared_data]
	ON [s_id] = [sb_subscriber] ;
GO

-- Trigger for subscriptions updat
CREATE TRIGGER [s_has_books_on_subscriptions_upd]
ON [subscriptions]
AFTER UPDATE
AS
-- (This is the DELETE-trigger code):
UPDATE [subscribers]
SET [s_books] = [s_books] - [s_old_books]
FROM [subscribers]
	JOIN (SELECT [sb_subscriber],
		COUNT ([sb_id]) AS [s_old_books]
	FROM [deleted]
	WHERE [sb_is_active] = 'Y'
	GROUP BY [sb_subscriber]) AS [prepared_data]
	ON [s_id] = [sb_subscriber] ;
-- (This is the INSERT-trigger code) :
UPDATE [subscribers]
SET [s_books] = [s_books] + [s_new_books]
FROM [subscribers]
	JOIN (SELECT [sb_subscriber] ,
		COUNT([sb_id]) AS [s_new_books]
	FROM [inserted]
	WHERE [sb_is_active] = 'Y'
	GROUP BY [sb_subscriber]) AS [prepared_data]
	ON [s_id] = [sb_subscriber] ;
GO

/* 4. Modify “genres” table to store the number of books in each
genre (and keep that data up-to-date).*/
-- Table modification:
ALTER TABLE [genres]
ADD [g_books] INT NOT NULL DEFAULT 0;

-- Data initialization:
UPDATE [genres]
SET [g_books] = [g_has_books]
FROM [genres]
    JOIN (SELECT [g_id],
    COUNT ([b_id]) AS [g_has_books]
    FROM [m2m_books_genres]
    GROUP BY [g_id]) AS [prepared_data]
    ON [genres].[g_id] = [prepared_data].[g_id];

SELECT *
FROM [genres]

-- Trigger for books-genres association insertion:
CREATE TRIGGER [g_has_books_on_m2m_b_g_ins]
ON [m2m_books_genres]
AFTER INSERT
AS
UPDATE [genres]
SET [g_books] = [g_books] + [g_new_books]
FROM [genres]
	JOIN (SELECT [g_id],
	COUNT ([b_id]) AS [g_new_books]
	FROM [inserted]
	GROUP BY [g_id]) AS [prepared_data]
	ON [genres].[g_id] = [prepared_data].[g_id];
GO

-- Trigger for books-genres association update:
CREATE TRIGGER [g_has_books_on_m2m_b_g_upd]
ON [m2m_books_genres]
AFTER UPDATE
AS
UPDATE [genres]
SET [g_books] = [g_books] + [delta]
FROM [genres]
	JOIN (SELECT [g_id],
			SUM([delta]) AS [delta]
		FROM (SELECT [g_id],
			COUNT ([b_id]) AS [delta]
			FROM [deleted]
			GROUP BY [g_id]
			UNION
			SELECT [g_id],
			COUNT ([b_id]) AS [delta]
			FROM [inserted]
			GROUP BY [g_id]) AS [raw_deltas]
		GROUP BY [g_id]) AS [ready_delta]
	ON [genres].[g_id] = [ready_delta].[g_id] ;
GO

-- Trigger for books-genres association deletion:
CREATE TRIGGER [g_has_books_on_m2m_b_g_del]
ON [m2m_books_genres]
AFTER DELETE
AS
UPDATE [genres]
SET [g_books] = [g_books] - [g_old_books]
FROM [genres]
JOIN (SELECT [g_id],
COUNT ([b_id]) AS [g_old_books]
FROM [deleted]
GROUP BY [g_id]) AS [prepared_data]
ON [genres].[g_id] = [prepared_data].[g_id];
GO

/* 03 - Using Triggers to Control Data Modification*/
/* 5. Create a trigger to prevent the following situations with subscriptions:
- subscription start date is in the future;
- subscription end date is in the past (for INSERT operations
only);
- subscription end date is less than subscription start date.*/

-- This approach blocks the hole operation regardless of how many "good" records are there:
CREATE TRIGGER [subscriptions_control]
ON [subscriptions] 
AFTER INSERT, UPDATE  /*We don’t need a DELETE-trigger as it’s impossible to violate any mentioned rules during DELETE operation */
AS
-- Variables to store "bad" records and the message:
DECLARE @bad_records NVARCHAR(max); 
DECLARE @msg NVARCHAR(max) ; 
-- Block aby subscription with the start date is in the future:
SELECT @bad_records = STUFF((SELECT ', ' + CAST([sb_id] AS NVARCHAR) +
		' (' + CAST([sb_start] AS NVARCHAR) + ')'
		FROM [inserted]
		WHERE [sb_start] > CONVERT (date, GETDATE () )
		ORDER BY [sb_id]
		FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)') ,
		1, 2, '');
IF LEN(@bad_records) > 0
BEGIN
SET @msg =
CONCAT('The following subscriptions'' activation dates are
in the future: ', @bad_records) ;
RAISERROR (@msg, 16, 1);
ROLLBACK TRANSACTION;
RETURN 
END; 
/* This is how to block an operation from within a trigger in MS SQL.*/

-- Block aby subscription with the end date is in the past:
DECLARE @deleted_records INT;
DECLARE @inserted_records INT; 
/*See the first part on the previous slide
ae and the last part on the next slide.*/
SELECT @deleted_records = COUNT(*) FROM [deleted] ;
SELECT @inserted_records = COUNT(*) FROM [inserted] ;

SELECT @bad_records = STUFF ((SELECT ', ' + CAST([sb_id] AS NVARCHAR) +
' (' + CAST([sb_start] AS NVARCHAR) + ')'
FROM [inserted]
WHERE [sb_finish] < CONVERT(date, GETDATE ())
ORDER BY [sb_id]
FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)') ,
1,2, '');
IF ((LEN(@bad_records) > 0) AND
(@deleted_records = 0) AND
(@inserted_records > 0))
BEGIN
SET @msg =
CONCAT('The following subscriptions'' deactivation dates are in the past: ', @bad_records) ;
RAISERROR (@msg, 16, 1);
ROLLBACK TRANSACTION ;
RETURN
END ;
-- Block any subscription with the end date less than the start date:
SELECT @bad_records = STUFF((SELECT ', ' + CAST([sb_id] AS NVARCHAR) +
' (act: ' + CAST([sb_start] AS NVARCHAR) + ', deact: ' +
CAST([sb_finish] AS NVARCHAR) + ')'
FROM [inserted]
WHERE [sb_finish] < [sb_start]
ORDER BY [sb_id]
FOR XML PATH(''), TYPE).value('.', 'nvarchar (max) ') ,
1, 2, '');
IF LEN(@bad_records) > 0
BEGIN
SET @msg =
CONCAT('The following subscriptions'' deactivation dates are less than activation dates: ', @bad_records) ;
RAISERROR (@msg, 16, 1);
ROLLBACK TRANSACTION;
RETURN
END ;
GO

DROP TRIGGER [subscriptions_control]
-- This approach blocks only "bad" records:
CREATE TRIGGER [subscriptions_control]
ON [subscriptions]
INSTEAD OF INSERT
AS
-- Variables to store records lists and corresponding messages:
DECLARE @bad_records_act_future NVARCHAR (max) ;
DECLARE @bad_records_deact_past NVARCHAR (max) ;
DECLARE @bad_records_act_greater_than_deact NVARCHAR (max) ;
DECLARE @good_records NVARCHAR (max) ;
DECLARE @msg NVARCHAR (max) ;

-- Block aby subscription with the start date is in the future:
SELECT @bad_records_act_future =
STUFF((SELECT ', ' + CAST([sb_start] AS NVARCHAR)
FROM [inserted]
WHERE [sb_start] > CONVERT(date, GETDATE())
ORDER BY [sb_start]
FOR XML PATH(''), TYPE).value('.', 'nvarchar (max) '),
1,2, '');
-- Block aby subscription with the end date is in the past:
SELECT @bad_records_deact_past =
STUFF((SELECT ', ' + CAST([sb_finish] AS NVARCHAR)
FROM [inserted]
WHERE [sb_finish] < CONVERT (date, GETDATE())
ORDER BY [sb_finish]
FOR XML PATH(''), TYPE).value('.', 'nvarchar (max) ') ,
1,2, '');
-- Block any subscription with the end date less than the start date:
SELECT @bad_records_act_greater_than_deact =
STUFF((SELECT ', (act: ' + CAST([sb_start] AS NVARCHAR) + 
', deact: ' + CAST([sb_finish] AS NVARCHAR) + ')'
FROM [inserted]
WHERE [sb_finish] < [sb_start]
ORDER BY [sb_start], [sb_finish]
FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)') ,
1, 2,'');

IF ((LEN(@bad_records_act_future) > 0) OR
(LEN (@bad_records_deact_past) > 0) OR
(LEN (@bad_records_act_greater_than_deact) > 0))
BEGIN
SET @msg = 'Some records were NOT inserted!';
IF (LEN(@bad_records_act_future) > 0)
BEGIN
SET @msg = CONCAT(@msg, CHAR(13), CHAR(10), 'The following activation dates are in the future: ',
@bad_records_act_future) ;    /*These are codes for “\r” and “\n”.*/
END;
IF (LEN(@bad_records_deact_past) > 0)
BEGIN
SET @msg = CONCAT(@msg, CHAR(13), CHAR(10), 'The following deactivation dates are in the past: ',
@bad_records_deact_past) ;
END;
IF (LEN(@bad_records_act_greater_than_deact) > 0)
BEGIN
SET @msg = CONCAT(@msg, CHAR(13), CHAR(10), 'The following deactivation dates are less than activation dates: ',
@bad_records_act_greater_than_deact) ;
END;
RAISERROR (@msg, 16, 1);
END;

SELECT @good_records = STUFF((SELECT ', ' +
		CAST([sb_start] AS NVARCHAR) + '/' +
		CAST ([sb_finish] AS NVARCHAR)
		FROM [inserted]
		WHERE (([sb_start] <= CONVERT (date, GETDATE())) AND
		([sb_finish] >= CONVERT(date, GETDATE())) AND
		([sb_finish] >= [sb_start]))
		ORDER BY [sb_start], [sb_finish]
		FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'),
		1,2, '');

IF LEN(@good_records) > 0
BEGIN
SET IDENTITY_INSERT [subscriptions] ON;
INSERT INTO [subscriptions]
([sb_id],
[sb_subscriber],
[sb_book] ,
[sb_start],
[sb_finish] ,
[sb_is_active])
SELECT ( CASE
		WHEN [sb_id] IS NULL
		OR [sb_id] = 0 THEN IDENT_CURRENT ('subscriptions') /*This is how we keep all “good” records.*/
		+ IDENT_INCR('subscriptions')
		+ ROW_NUMBER() OVER (ORDER BY (SELECT 1))
		-1
		ELSE [sb_id]
	END ) AS [sb_id],
[sb_subscriber],
[sb_book] ,
[sb_start],
[sb_finish],
[sb_is_active]
FROM [inserted]
WHERE (([sb_start] <= CONVERT (date, GETDATE())) AND
([sb_finish] >= CONVERT (date, GETDATE())) AND
([sb_finish] >= [sb_start]));
SET IDENTITY_INSERT [subscriptions] OFF;
SET @msg =
CONCAT ('Subscriptions with the following activation/deactivation dates were inserted successfully: ', @good_records);
PRINT @msg;
END;
GO

/* 6. Create a trigger to prevent creation of a new subscription for a
subscriber already having 10 (and more) books taken.*/
CREATE TRIGGER [sbs_cntrl_10_books_ins_OK]
ON [subscriptions]
INSTEAD OF INSERT
AS
	DECLARE @bad_records NVARCHAR (max) ;
	DECLARE @msg NVARCHAR (max) ;
SELECT @bad_records = STUFF((SELECT ', ' + [list]
							FROM (SELECT CONCAT('(id=', [s_id], ', ',
										[s_name], ', books=',
										COUNT([sb_book]), ')') AS [list]
									FROM [subscribers]
									JOIN [subscriptions] ON [s_id] = [sb_subscriber]
									WHERE [sb_is_active] = 'Y'
									AND [sb_subscriber] IN 
													(SELECT [sb_subscriber]
													FROM [inserted])
									GROUP BY [s_id], [s_name]
									HAVING COUNT([sb_book]) >= 10)
									AS [prepared_data]
		FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1,2, '');
IF (LEN(@bad_records) > 0)
BEGIN
SET @msg = CONCAT('The following readers have more books than allowed (10 allowed): ', @bad_records) ;
RAISERROR (@msg, 16, 1);
ROLLBACK TRANSACTION;
RETURN;
END;

SET IDENTITY_INSERT [subscriptions] ON;
INSERT INTO [subscriptions]
			([sb_id],
			[sb_subscriber] ,
			[sb_book] ,
			[sb_start],
			[sb_finish],
			[sb_is_active])
SELECT ( CASE
			WHEN [sb_id] IS NULL
				OR [sb_id] = 0 THEN IDENT_CURRENT ('subscriptions')
									+ IDENT_INCR('subscriptions')
									+ ROW_NUMBER() OVER (ORDER BY
													(SELECT 1))
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
GO

/* 7. Create a trigger to prevent modifying a subscription from
inactive state back to active (i.e. from modifying “sb_is_active”
field value from “N” to “Y”).*/
CREATE TRIGGER [sbs_cntrl_is_active]
ON [subscriptions]
AFTER UPDATE
AS
DECLARE @bad_records NVARCHAR (max) ;
DECLARE @msg NVARCHAR (max) ;
/*We need id’s in the error message, so we block the surrogate PK update.*/
IF (UPDATE ([sb_id])) 
BEGIN
RAISERROR ('Please, do NOT update surrogate PK on table [subscriptions]!', 16, 1);
ROLLBACK TRANSACTION ;
RETURN ;
END ;
SELECT @bad_records =
		STUFF((SELECT ', ' + CAST ([inserted].[sb_id] AS NVARCHAR)
		FROM [deleted]
		JOIN [inserted] ON [deleted].[sb_id] = [inserted].[sb_id]
		WHERE [deleted].[sb_is_active] = 'N'
		AND [inserted].[sb_is_active] = 'Y'
	FOR XML PATH(''), TYPE) .value('.', 'nvarchar(max)'),
	1, 2, '');
IF (LEN(@bad_records) > 0)
BEGIN
SET @msg = CONCAT('It is prohibited to activate previously deactivated subscriptions (rule violated for
					subscriptions with id ', @bad_records, ').');
RAISERROR (@msg, 16, 1);
ROLLBACK TRANSACTION ;
RETURN ;
END ;
GO

/* 04 - Using Triggers to Control Data Format and Values */
/* 8. Create a trigger to only allow registration of subscribers with a
dot and at least two words in their names.*/
-- MS SQL allows to assign one trigger to different actions, but here we follow MySQL approach to simplify trigger code.
CREATE TRIGGER [sbsrs_ontrl_name_ins] 
ON [subscribers]
INSTEAD OF INSERT
AS
DECLARE @bad_records NVARCHAR (max) ;
DECLARE @msg NVARCHAR (max) ;
SELECT @bad_records = STUFF((SELECT ', ' + [s_name]
							FROM [inserted]
							WHERE
						CHARINDEX(' ', LTRIM(RTRIM([s_name]))) = 0 OR CHARINDEX('.', [s_name]) = 0
						FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'),
						1,2, '');
-- MS SQL does not support PCRE regular expressions, SO we may use such a simplified  approach only.
IF (LEN(@bad_records) > 0)
BEGIN 
SET @msg = CONCAT('Subscribers name should contain at least two wo int, but the following names
violate this rule: ', @bad_records) ;
RAISERROR (@msg, 16, 1);
ROLLBACK TRANSACTION;
RETURN;
END;

SET IDENTITY_INSERT [subscribers] ON;
INSERT INTO [subscribers]
			([s_id], [s_name])
SELECT ( CASE
			WHEN [s_id] IS NULL
			OR [s_id] = 0 THEN IDENT_CURRENT ('subscribers')
				+ IDENT_INCR('subscribers')
				+ ROW_NUMBER() OVER (ORDER BY
				(SELECT 1))
				-1
		ELSE [s_id]
	END ) AS [s_id], [s_name]
FROM [inserted] ;
SET IDENTITY_INSERT [subscribers] OFF;
GO

CREATE TRIGGER [sbsrs_ontrl_name_upd] 
ON [subscribers]
INSTEAD OF UPDATE /*Pay attention: we use INSTEAD OF triggers here!*/
/*MS SQL allows to assign one trigger to different
actions, but here we follow MySQL approach to
simplify trigger code.*/
AS
DECLARE @bad_records NVARCHAR (max) ;
DECLARE @msg NVARCHAR (max) ;
IF (UPDATE([s_id]))
BEGIN
RAISERROR ('Please, do NOT update surrogate PK on table [subscribers]!', 16, 1);
ROLLBACK TRANSACTION ;
RETURN;
END;

SELECT @bad_records = STUFF((SELECT ', ' + [s_name]
							FROM [inserted]
							WHERE
						CHARINDEX(' ', LTRIM(RTRIM([s_name]))) = 0
						OR CHARINDEX('.', [s_name]) = 0
			FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)') ,
			1, 2, '');
IF (LEN(@bad_records) > 0)
BEGIN
SET @msg = CONCAT('Subscribers name should contain at least two words and one point, but the following names
					violate this rule: ', @bad_records) ;
RAISERROR (@msg, 16, 1);
ROLLBACK TRANSACTION ;
RETURN;
END;

UPDATE [subscribers]
SET [subscribers].[s_name] = [inserted].[s_name]
FROM [subscribers]
	JOIN [inserted] ON [subscribers].[s_id] = [inserted].[s_id];
GO

/* 9. Create a trigger to only allow registration of books issued no
more than 100 years ago.*/
CREATE TRIGGER [books_cntrl_year_ins_upd] 
ON [books]
AFTER INSERT, UPDATE 
/* MS SQL allows to assign one trigger to different
actions, and here we use AFTER triggers (not
INSTEAD OF like in previous solution): this is
slower, but much simpler.*/
AS
DECLARE @bad_records NVARCHAR (max) ;
DECLARE @msg NVARCHAR (max) ;

SELECT @bad_records = STUFF((SELECT ', ' + CAST([b_year] AS NVARCHAR)
							FROM [inserted]
							WHERE (YEAR(GETDATE()) - [b_year]) > 100
					FOR XML PATH(''), TYPE) .value('.', 'nvarchar(max)'),
					1, 2, '');
IF (LEN (@bad_records) > 0)
BEGIN
SET @msg = CONCAT('The following issuing years are more
than 100 years in the past: ', @bad_records) ;
RAISERROR (@msg, 16, 1);
ROLLBACK TRANSACTION ;
RETURN ;
END ;
GO

/* 05 - Using Triggers to Correct Data On-the-Fly*/
/* 10. Create a trigger to check if there is a dot at the end of
subscriber’s name and to add a such dot if there is no one.*/
CREATE TRIGGER [sbsrs_name_lp_ins]
ON [subscribers]
INSTEAD OF INSERT
AS
DECLARE @bad_records NVARCHAR (max) ;
DECLARE @msg NVARCHAR (max) ;

SELECT @bad_records = STUFF((SELECT ', ' + '[' + [s_name] + '] -> [' + [s_name] + ']'
							FROM [inserted]
							WHERE RIGHT ([s_name], 1) <> '.'
							FOR XML PATH(''), TYPE).value('.', 'nvarchar (max)') ,
							1,2,'');
IF (LEN(@bad_records) > 0)
BEGIN
SET @msg = CONCAT('Some values were changed: ', @bad_records) ;
PRINT @msg;
RAISERROR (@msg, 16, 0) ;
END;

SET IDENTITY_INSERT [subscribers] ON;
INSERT INTO [subscribers]
			([s_id],
			[s_name])
SELECT ( CASE
			WHEN [s_id] IS NULL
			OR [s_id] = 0 THEN IDENT_CURRENT ('subscribers')
							+ IDENT_INCR('subscribers')
							+ ROW_NUMBER() OVER (ORDER BY (SELECT 1))
							-1
						ELSE [s_id]
			END ) AS [s_id],
		( CASE
			WHEN RIGHT ([s_name], 1) <> '.'
			THEN CONCAT([s_name], '.')
			ELSE [s_name]
		END ) AS [s_name]
FROM [inserted] ;
SET IDENTITY_INSERT [subscribers] OFF;
GO

CREATE TRIGGER [sbsrs_name_lp_upd]
ON [subscribers]
INSTEAD OF UPDATE
AS
DECLARE @bad_records NVARCHAR (max) ;
DECLARE @msg NVARCHAR (max) ;

IF (UPDATE ([s_id]))
BEGIN
RAISERROR ('Please, do not update surrogate PK on table [subscribers]!', 16, 1);
ROLLBACK TRANSACTION;
RETURN;
END;

SELECT @bad_records = STUFF((SELECT ', ' + '[' + [s_name] + '] -> [' + [s_name] + ']'
							FROM [inserted]
							WHERE RIGHT ([s_name], 1) <> '.'
							FOR XML PATH(''), TYPE).value('.', 'nvarchar (max)') ,
							1,2,'');
IF (LEN(@bad_records) > 0)
BEGIN
SET @msg = CONCAT('Some values were changed: ', @bad_records) ;
PRINT @msg;
RAISERROR (@msg, 16, 0) ;
END;

UPDATE [subscribers] 
SET [subscribers].s_name =
		 ( CASE
			WHEN RIGHT ([inserted].[s_name], 1) <> '.'
			THEN CONCAT([inserted].[s_name], '.')
			ELSE [inserted].[s_name]
		END ) 
FROM [subscribers]
JOIN [inserted] ON [subscribers].s_id = inserted.s_id;
GO

/* 11. Create a trigger to change the subscription end date to “current
date + two months” if the given end date is in the past or is less than the start date.*/
CREATE TRIGGER [sbscs_date_tm_ins]
ON [subscriptions] 
INSTEAD OF INSERT
AS 
DECLARE @bad_records NVARCHAR(max) ;
DECLARE @msg NVARCHAR(max) ;

SELECT @bad_records =
			STUFF ((SELECT ', ' + '[' + CAST([sb_finish] AS NVARCHAR) +
					'] -> [' + FORMAT(DATEADD(month, 2, GETDATE()),
					'yyyy-MM-dd') + ']'
					FROM [inserted]
					WHERE ([sb_finish] < [sb_start]) OR
						([sb_finish] < GETDATE())
				FOR XML PATH(''), TYPE) .value('.', 'nvarchar(max)'),
				1, 2, '');
IF (LEN (@bad_records) > 0)
BEGIN
SET @msg = CONCAT('Some values were changed: ', @bad_records) ;
PRINT @msg;
RAISERROR (@msg, 16, 0);
END ;

SET IDENTITY_INSERT [subscriptions] ON;
INSERT INTO [subscriptions]
			([sb_id],
			[sb_subscriber] ,
			[sb_book] ,
			[sb_start],
			[sb_finish] ,
			[sb_is_active])
SELECT ( CASE
			WHEN [sb_id] IS NULL
			OR [sb_id] = 0 THEN IDENT_CURRENT ('subscriptions')
								+ IDENT_INCR('subscriptions')
								+ ROW_NUMBER() OVER (ORDER BY (SELECT 1))
								-1
							ELSE [sb_id]
		END ) AS [sb_id],
	[sb_subscriber] ,
	[sb_book] ,
	[sb_start],
( CASE
	WHEN (([sb_finish] < [sb_start]) OR
	([sb_finish] < GETDATE()))
	THEN DATEADD(month, 2, GETDATE())
	ELSE [sb_finish]
END ) AS [sb_finish],
[sb_is_active]
FROM [inserted] ;
SET IDENTITY_INSERT [subscriptions] OFF;
GO

-- Attentions! In order to create this trigger you should disable cascade update
-- on [subscriptions] foreign keys. And this requires you to modify the trigger to
-- maintain referential integrity.
CREATE TRIGGER [sbscs_date_tm_upd]
ON [subscriptions] 
INSTEAD OF UPDATE 
AS 
DECLARE @bad_records NVARCHAR(max) ; 
DECLARE @msg NVARCHAR(max) ;
IF (UPDATE ([sb_id]))
BEGIN
RAISERROR ('Please, do NOT update surrogate PK on table [subscriptions]!', 16, 1);
ROLLBACK TRANSACTION;
RETURN;
END ;

SELECT @bad_records =
			STUFF((SELECT ', ' + '[' + CAST([sb_finish] AS NVARCHAR) +
			'] -> [' + FORMAT(DATEADD(month, 2, GETDATE()),
			'yyyy-MM-dd') + ']'
					FROM [inserted]
					WHERE ([sb_finish] < [sb_start]) OR
					([sb_finish] < GETDATE())
					FOR XML PATH(''), TYPE) .value('.', 'nvarchar(max)') ,
					1,2, '');
IF (LEN(@bad_records) > 0)
BEGIN
SET @msg = CONCAT('Some values were changed: ', @bad_records) ;
PRINT @msg;
RAISERROR (@msg, 16, 0); 
-- With INSTEAD OF triggers we have to perform corresponding operation "manually", i.e. by our own code
END; 

UPDATE [subscriptions] 
SET [subscriptions].[sb_subscriber] = [inserted].[sb_subscriber],
[subscriptions].[sb_book] = [inserted].[sb_book],
[subscriptions].[sb_start] = [inserted].[sb_start],
[subscriptions].[sb_finish] =
	( CASE
	WHEN (([inserted].[sb_finish] < [inserted].[sb_start]) OR
		([inserted].[sb_finish] < GETDATE()))
	THEN DATEADD(month, 2, GETDATE() )
	ELSE [inserted].[sb_finish]
	END ),
[subscriptions].[sb_is_active] = [inserted].[sb_is_active]
FROM [subscriptions]
JOIN [inserted]
ON [subscriptions].[sb_id] = [inserted].[sb_id];
GO