/* 1. Create a stored function that receives a subscription start and
end dates and returns the difference (in days) along with
suffixes:
[OK], if the difference is less than 10 days;
[NOTICE], if the difference is between 10 and 30 days;
[WARNING], if the difference is more than 30 days.*/
CREATE FUNCTION READ_DURATION_AND_STATUS (@start_date DATE, @finish_date DATE)
RETURNS NVARCHAR (150)
WITH SCHEMABINDING
AS
BEGIN
DECLARE @days INT;
DECLARE @message NVARCHAR (150) ;
SET @days = DATEDIFF(day, @start_date, @finish_date) ;
SET @message =
	CASE
		WHEN (@days<10) THEN ' OK'
		WHEN ((@days>=10) AND (@days<=30)) THEN ' NOTICE!'
		WHEN (@days>30) THEN ' WARNING'
	END ;
RETURN CONCAT(@days, @message) ;
END ;
GO

SELECT sb_id, sb_start, sb_finish,
dbo.READ_DURATION_AND_STATUS(sb_start, sb_finish) AS rdns
FROM subscriptions
WHERE sb_is_active = 'Y';

DROP FUNCTION READ_DURATION_AND_STATUS

/* 2. Create a stored function that returns “empty values” of a
primary key of a table. E.g.: for 1, 3, 8 primary key values
“empty values” are: 2, 4, 5, 6, 7.*/
-- MSSQL has the following limitation:
-- dynamic SQL is not allowed in stored functions (so, we may process only one pre-defined table);
-- ! But supports table-valued functions
CREATE FUNCTION GET_FREE_KEYS_IN_SUBSCRIPTIONS()
RETURNS @free_keys TABLE
(
[start] INT,
[stop] INT
)
AS
BEGIN
INSERT @free_keys
SELECT [start], [stop]
FROM (SELECT [min_t].[sb_id] + 1  AS [start],
			(SELECT MIN([sb_id]) - 1
			FROM [subscriptions] AS [x]
			WHERE [x].[sb_id] > [min_t].[sb_id]) AS [stop]
		FROM [subscriptions] AS [min_t]
		UNION
		SELECT 1             AS [start],
				(SELECT MIN([sb_id]) - 1
				FROM [subscriptions] AS [x]
				WHERE [sb_id] > 0)  AS [stop]
		) AS [data]
WHERE [stop] >= [start]
ORDER BY [start], [stop]
RETURN
END;
GO 

SELECT GET_FREE_KEYS_IN_SUBSCRIPTIONS()
FROM subscriptions

/* 02 - Using Stored Functions for Data Control */
/* 4. Create a stored function that checks all three conditions from
“Using Triggers to Control Data Modification” topic’s Task 1 and
returns a negative number, modulo value of which is equal to
the number of a violated rule.*/
CREATE FUNCTION CHECK_SUBSCRIPTION_DATES (@sb_start DATE,
											@sb_finish DATE,
											@is_insert INT)
RETURNS INT
WITH SCHEMABINDING
AS
BEGIN
DECLARE @result INT = 1;

-- If the subscription start date is in the future:
IF (@sb_start > CONVERT(date, GETDATE()))
BEGIN
SET @result = -1;
END;

-- If the subscription end date is in the past:
IF ((@sb_finish < CONVERT(date, GETDATE())) AND (@is_insert = 1))
BEGIN
SET @result = -2;
END;

-- If the subscription start date is less than the end date:
IF (@sb_finish < @sb_start)
BEGIN
SET @result = -3;
END;

RETURN @result;
END ;

/* 5. Create a stored function that checks the condition from “Using
Triggers to Control Data Format and Values” topic’s Task 1 and
returns 1 if the condition is met, and O otherwise.

Create a trigger to only allow registration of subscribers with a
dot and at least two words in their names.
[Return 1] if the condition is met.
[Return 0] if the condition is violated */
CREATE FUNCTION CHECK_SUBSCRIBER_NAME (@subscriber_name NVARCHAR(150) )
RETURNS INT
WITH SCHEMABINDING
AS
BEGIN
DECLARE @result INT = -1;
IF ((CHARINDEX(' ', LTRIM(RTRIM(@subscriber_name))) = 0) OR
(CHARINDEX('.', @subscriber_name) = 0))
BEGIN
SET @result = 0;
END
ELSE 
BEGIN
SET @result = 1;
END; 
RETURN @result; 
END; 
GO

SELECT s_name, CHECK_SUBSCRIBER_NAME(s_name)
FROM subscribers;

/* 03 - Using Stored Procedures to Execute Dynamic Queries */
/* 6. Create a stored procedure that “compresses” all “empty values”
of a primary key of a table and returns the number of modified
values. E.g.: for 1, 3, 8 primary key values the new sequence
should be: 1, 2, 3, and the returned value should be 1.*/
CREATE PROCEDURE COMPACT_KEYS
@table_name NVARCHAR (150) ,
@pk_name NVARCHAR (150) ,
@keys_changed INT OUTPUT
WITH EXECUTE AS OWNER
AS
DECLARE @empty_key_query NVARCHAR(1000) = '';
DECLARE @max_key_query NVARCHAR(1000) = '';
DECLARE @empty_key_value INT = NULL;
DECLARE @max_key_value INT = NULL;
DECLARE @update_key_query NVARCHAR(1000) = '';
DECLARE @error_message NVARCHAR(1000) = '';

IF (COLUMNPROPERTY (OBJECT_ID(@table_name), @pk_name, 'IsIdentity') = 1)
-- We can not modify identity fields
BEGIN
SET @keys_changed = -1;
SET @error_message = CONCAT('Remove identity property for column [',
@pk_name,'] of table [', @table_name, '] via MS SQL Server Management Studio.') ;
RAISERROR (@error_message, 16, 1);
RETURN -1;
END;

SET @keys_changed = 0;

-- This is for debug only:
PRINT (CONCAT('Point 1. @table_name = ', @table_name, ', @pk_name = ',
@pk_name, ', @keys changed = ', ISNULL(@keys_changed, 'NULL'))) ;

SET @empty_key_query =   /* Here we prepare the query to fetch all "empty keys" values */
CONCAT('SET @empty_k_v = (SELECT MIN([empty_key]) AS [empty_key]
FROM (SELECT [left].[', @pk_name, '] + 1 AS [empty_key]
FROM [', @table_name, '] AS [left]
LEFT OUTER JOIN [', @table_name, '] AS [right]
ON [left].[', @pk_name,
'] + 1 = [right].[', @pk_name, ']
WHERE [right].[', @pk_name, '] IS NULL
UNION
SELECT 1 AS [empty_key]
FROM [', @table_name, ']
WHERE NOT EXISTS(SELECT [', @pk_name, ']
FROM [', @table_name, ']
WHERE [', @pk_name, '] = 1)
) AS [prepared_data]
WHERE [empty_key] < (SELECT MAX([', @pk_name, '])
FROM [', @table_name, ']))');

SET @max_key_query =
CONCAT('SET @max_k_v = (SELECT MAX([', @pk_name, ']) FROM [',
@table_name, '])');

-- This is for debug only:
PRINT (CONCAT('Point 2. @empty_key query = ', @empty_key_query,
CHAR(13), CHAR(10), '@max_key_query = ', @max_key_query)) ;

WHILE (1 = 1)
BEGIN 
EXECUTE sp_executesql @empty_key_query, /*Now we get all “empty keys” values,loop through this set...*/
					N'@empty_k_v INT OUT', 
					@empty_key_value OUTPUT; 
IF (@empty_key_value IS NULL)
BREAK ;

EXECUTE sp_executesql @max_key_query,
						N'@max_k_v INT OUT',
						@max_key_value OUTPUT;
SET @update_key_query =
CONCAT('UPDATE [', @table_name, '] SET [', @pk_name, 
'] = ', @empty_key_value, ' WHERE [', @pk_name, '] = ', 
@max_key_value) ;

-- This is for debug only.
PRINT (CONCAT('Point 3. @update_key_query = ', @update_key_query)) ;

-- .. and modify corresponding values.
EXECUTE sp_executesql @update_key_query;
SET @keys_changed = @keys_changed + 1; 
END;
GO

DECLARE @res INT;
EXECUTE COMPACT_KEYS 'subscriptions', 'sb_id', @res OUTPUT;
SELECT @res;
GO

DECLARE @res INT;
EXECUTE COMPACT_KEYS 'books', 'b_id', @res OUTPUT;
SELECT @res;
GO

SELECT * FROM [subscriptions];
SELECT * FROM [books] ORDER BY [b_quantity];

/* 7. Create a stored procedure that makes a list of all views, triggers
and foreign keys for a given table.*/
CREATE PROCEDURE SHOW_TABLE_OBJECTS
@table_name NVARCHAR (150)
WITH EXECUTE AS OWNER
AS
DECLARE @query_text NVARCHAR(1000) = '';
SET @query_text =
'SELECT ''foreign_key'' AS [object_type],
[constraint_name] AS [object_name]
FROM  [information_schema].[table_constraints]
WHERE [table_catalog] = DB_NAME()
AND [table_name] = ''_FP_TABLE_NAME_PLACEHOLDER_''
AND [constraint_type] = ''FOREIGN KEY''
UNION
SELECT ''trigger'' AS [object_type],
[name] AS [object_name]
FROM [sys].[triggers]
WHERE OBJECT_NAME([parent_id]) = ''_FP_TABLE_NAME_PLACEHOLDER_''
UNION
SELECT ''view'' AS [object_type],
[table_name] AS [object_name]
FROM  [information_schema].[views]
WHERE [table_catalog] = DB_NAME()
AND [view_definition] LIKE ''%[_FP_TABLE_NAME_PLACEHOLDER_]%''';

SET @query_text = REPLACE(@query_text, '_FP_TABLE_NAME_PLACEHOLDER_',
@table_name) ;
EXECUTE sp_executesql @query_text;
GO

EXECUTE SHOW_TABLE_OBJECTS 'subscriptions'

/* 04 - Using Stored Procedures for Performance Optimization */
/* 8. Create a stored procedure that is scheduled to update
“books_statistics” table (see “Using Caching Views and Tables
to Select Data” topic’s Task 1) every hour. */
CREATE PROCEDURE UPDATE_BOOKS_STATISTICS
AS
-- Let’s check if the table exists.
IF (NOT EXISTS(SELECT *
FROM [information_schema].[tables]
WHERE [table_catalog] = DB_NAME()
AND [table_name] = 'books_statistics'))
BEGIN
RAISERROR ('The [books statistics] table is missing.', 16, 1);
RETURN;
END;
-- Here we update the table.
UPDATE [books_statistics]
SET
[books_statistics].[total] = [src].[total],
[books_statistics].[given] =[src].[given] ,
[books_statistics].[rest] = [src].[rest]
FROM [books_statistics]
JOIN
(SELECT ISNULL([total], 0) AS [total],
ISNULL([given], 0) AS [given],
ISNULL([total] - [given], 0) AS [rest]
FROM (SELECT (SELECT SUM([b_quantity])
FROM [books]) AS [total],
(SELECT COUNT([sb_book])
FROM [subscriptions]
WHERE [sb_is_active] = 'Y') AS [given])
AS [prepared_data]
) AS [src]
ON 1=1;
GO

EXECUTE UPDATE_BOOKS_STATISTICS; 

USE msdb ;
GO
-- https: //msdn.microsoft.com/en-us/library/ms182079.aspx
EXEC dbo.sp_add_job
@job_name = N'Hourly [books_statistics] update';
GO
-- https: //msdn.microsoft.com/en-us/library/ms187358.aspx
EXEC sp_add_jobstep
@job_name = N'Hourly [books statistics] update',
@step_name = N'Execute UPDATE_BOOKS_STATISTICS stored procedure',
@subsystem = N'TSQL',
@command = N'EXECUTE UPDATE_BOOKS_STATISTICS',
@database_name = N'library_eng';
GO
-- https: //msdn.microsoft .com/en-us/library/ms187320.aspx
EXEC dbo.sp_add_schedule
@schedule_name = N'UpdateBooksStatistics',
@freq_type = 4,
@freq_interval = 4,
@freq_subday_type = 8,
@freq_subday_interval = 1,
@active_start_time = 000100 ;
USE msdb ;
GO
-- https: //msdn microsoft .com/en-us/library/ms186766.aspx
EXEC sp_attach_schedule
@job_name = N'Hourly [books statistics] update',
@schedule_name = N'UpdateBooksStatistics' ;
GO
-- https: //msdn microsoft .com/en-us/library/ms178625.aspx
EXEC dbo.sp_add_jobserver
@job_name = N'Hourly [books_statistics] update';
GO

SELECT * FROM msdb.dbo.sysschedules;

/* 9. Create a stored procedure that is scheduled to optimize
(compress) all database tables once per day.*/
CREATE PROCEDURE OPTIMIZE_ALL_TABLES
AS
BEGIN
DECLARE @table_name NVARCHAR(200) ;
DECLARE @index_name NVARCHAR(200) ;
DECLARE @avg_fragm_perc DOUBLE PRECISION;
DECLARE @query_text NVARCHAR(2000) ;
DECLARE indexes_cursor CURSOR LOCAL FAST_FORWARD FOR
/* Here we retrieve the list of all tables along wit
their clustered indexes (we need that indexes to
understand the fragmentation rate and to
optimize the table).*/
SELECT DISTINCT
[tables].[name] AS [table_name],
[indexes].[name] AS [index_name],
[stats].[avg_fragmentation_in_percent] AS [avg_fragm_perc]
FROM sys.indexes AS [indexes]
INNER JOIN sys.tables AS [tables]
ON [indexes].[object_id] = [tables].[object_id]
INNER JOIN sys.dm_db_index_physical_stats(DB_ID(DB_NAME()),
NULL, NULL, NULL,
'SAMPLED') AS [stats]
ON [indexes].[object_id] = [stats].[object_id]
AND [indexes].[index_id] = [stats].[index_id]
WHERE [indexes].[type] = 1
ORDER BY [tables].[name],
[indexes].[name] ;
OPEN indexes_cursor;
FETCH NEXT FROM indexes_cursor INTO @table_name,
@index_name,
@avg_fragm_perc;

WHILE @@FETCH_STATUS = 0
-- We may either reorganize a table ...
BEGIN
IF (@avg_fragm_perc >= 5.0) AND (@avg_fragm_perc <= 30.0) 
BEGIN
SET @query_text = CONCAT('ALTER INDEX [', @index_name, 
'] ON [', @table_name, '] REORGANIZE') ; 
PRINT CONCAT('Index [', @index_name,'] ON [', @table_name,
'] will be REORGANIZED...') ;
EXECUTE sp_executesql @query_text;
END;
-- or rebuild a table ...
IF (@avg_fragm_perc > 30.0)
BEGIN 
SET @query_text = CONCAT('ALTER INDEX [', @index_name,'] ON [',
@table_name, '] REBUILD') ;
PRINT CONCAT('Index [', @index_name,'] on [', @table_name,
'] will be REBUILT...');
EXECUTE sp_executesql @query_text;
END;
-- ... or leave it “as is” (in case it is not fragmented in any significant way).
IF (@avg_fragm_perc < 5.0)  
BEGIN 
PRINT CONCAT('Index [', @index_name,'] on [', @table_name,
'] needs no optimization...'); 
END; 

FETCH NEXT FROM indexes_cursor INTO @table_name,
@index_name,
@avg_fragm_perc;
END;
CLOSE indexes_cursor;
DEALLOCATE indexes_cursor;
END;
GO

EXECUTE OPTIMIZE_ALL_TABLES

USE msdb ;
GO
-- https: //msdn.microsoft.com/en-us/library/ms182079.aspx
EXEC dbo.sp_add_job
@job_name = N'DailyoptimizeallTables' ;
GO
-- https: //msdn.microsoft.com/en-us/library/ms187358 .aspx
EXEC sp_add_jobstep
@job_name = N'Dailyoptimizealltables',
@step_name = N'Execute OPTIMIZE_ALL_TABLES stored procedure',
@subsystem = N'TSQL',
@command = N'EXECUTE OPTIMIZE_ALL_TABLES',
@database_name = N'library_ex_2015_mod';
GO
-- https: //msdn.microsoft .com/en-us/library/ms187320.aspx
EXEC dbo.sp_add_schedule
@schedule_name = N'UpdateBooksStatistics',
@freq_type = 4,
@freq_interval = 4,
@freq_subday_type = 1,
@freq_subday_interval = 1,
@active_start_time = 000105 ;
USE msdb ;
GO
-- https: //msdn.microsoft .com/en-us/library/ms186766.aspx
EXEC sp_attach_schedule
@job_name = N'DailyoptimizeaAllTables',
@schedule_name = N'DailyoptimizeAllTables' ;
GO
-- https: //msdn.microsoft .com/en-us/library/ms178625.aspx
EXEC dbo.sp_add_jobserver
@job_name = N'DailyoptimizeallTables' ;
GO

SELECT * FROM msdb.dbo.sysschedules;

/* 05 - Using Stored Procedures to Manipulate Database Objects */
/* 10. Create a stored procedure that automatically creates and
populates with data “books_statistics” table (see “Using
Caching Views and Tables to Select Data” topic’s Task 1).*/
CREATE PROCEDURE CREATE_BOOKS_STATISTICS
AS
BEGIN
-- Check, if table exists.
IF NOT EXISTS
(SELECT [name]
FROM sys.tables
WHERE [name] = 'books_statistics')
-- Create table, if not exists.
BEGIN
CREATE TABLE [books_statistics]
(
[total] INTEGER NOT NULL,
[given] INTEGER NOT NULL,
[rest] INTEGER NOT NULL
);
-- Populate table with data.
INSERT INTO [books_statistics]
([total] ,
[given],
[rest])
SELECT ISNULL([total], 0) AS [total],
ISNULL([given], 0) AS [given],
ISNULL([total] - [given], 0) AS [rest]
FROM (SELECT (SELECT SUM([b_quantity])
				FROM [books]) AS [total],
				(SELECT COUNT ([sb_book])
				FROM [subscriptions]
				WHERE [sb_is_active] = 'Y') AS [given])
AS [prepared_data] ;
END;
ELSE
BEGIN
-- Just update table, if exists.
UPDATE [books_statistics]
SET
[books_statistics].[total] = [src].[total],
[books_statistics].[given] = [src].[given], 
[books_statistics].[rest] = [src].[rest]
FROM [books_statistics]
JOIN
(SELECT ISNULL([total], 0) AS [total],
ISNULL([given], 0) AS [given],
ISNULL([total] - [given], 0) AS [rest]
FROM (SELECT (SELECT SUM([b_quantity])
FROM [books] ) AS [total],
(SELECT COUNT([sb_book])
FROM [subscriptions]
WHERE [sb_is_active] = 'Y') AS [given])
AS [prepared_data]
) AS [src]
ON 1=1;
END ;
END;
GO

DROP TABLE books_statistics;
EXECUTE CREATE_BOOKS_STATISTICS;
SELECT * FROM books_statistics;

/* 11. Create a stored procedure that automatically creates and
populates with data “tables_rc” table that contains all database
tables names along with records count for each table.*/
CREATE PROCEDURE CACHE_TABLES_RC
AS
BEGIN
DECLARE @table_name NVARCHAR (200) ;
DECLARE @table_rows INT;
DECLARE @query_text NVARCHAR (2000) ;
DECLARE tables_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT [name]
FROM sys.tables;
-- Check, if table exists.
IF NOT EXISTS
(SELECT [name]
FROM sys.tables
WHERE [name] = 'tables_rc')
BEGIN
-- Create table, if not exists.
CREATE TABLE [tables_rc]
(
[table_name] VARCHAR (200) ,
[rows_count] INT
);
END ;
/* Clear table. WARNING! In real production
environment some applications may crash if they
don’t expect this table to be empty.*/
TRUNCATE TABLE [tables_rc];
OPEN tables_cursor;
FETCH NEXT FROM tables_cursor INTO @table_name;
WHILE @@FETCH_STATUS = 0
BEGIN
SET @query_text = CONCAT('SELECT @cnt = COUNT(1) FROM [',
@table_name, ']');
EXECUTE sp_executesql @query_text, N'@cnt INT OUT', @table_rows OUTPUT;
-- Populate table with data.
INSERT INTO [tables_rc] ([table_name], [rows_count])
VALUES (@table_name, @table_rows) ;
FETCH NEXT FROM tables_cursor INTO @table_name;
END ;
CLOSE tables_cursor;
DEALLOCATE tables_cursor;
END;
GO

EXECUTE CACHE_TABLES_RC;
SELECT * FROM tables_rc;



 



 

 

 


 
  
 
 

 



  

 

  

