## Contents of sql files
**01 - Using Stored Functions for Data Operations**
1. Create a stored function that receives a subscription start and end dates and returns the difference (in days) along with suffixes:
\[OK], if the difference is less than 10 days;
\[NOTICE], if the difference is between 10 and 30 days;
\[WARNING], if the difference is more than 30 days.
2. Create a stored function that returns “empty values” of a primary key of a table. E.g.: for 1, 3, 8 primary key values “empty values” are: 2, 4, 5, 6, 7.
3. Create a stored function that updates “books_statistics” table (see. “Using Caching Views and Tables to Select Data” topic) and returns a delta of registered books count.      

**02 - Using Stored Functions for Data Control**

4. Create a stored function that checks all three conditions from “Using Triggers to Control Data Modification” topic’s Task 1 and returns a negative number, modulo value of which is equal to the number of a violated rule.
5. Create a stored function that checks the condition from “Using Triggers to Control Data Format and Values” topic’s Task 1 and returns 1 if the condition is met, and O otherwise.      

**03 - Using Stored Procedures to Execute Dynamic Queries**

6. Create a stored procedure that “compresses” all “empty values” of a primary key of a table and returns the number of modified values. E.g.: for 1, 3, 8 primary key values the new sequence should be: 1, 2, 3, and the returned value should be 1.
7. Create a stored procedure that makes a list of all views, triggers and foreign keys for a given table.      

**04 - Using Stored Procedures for Performance Optimization**

8. Create a stored procedure that is scheduled to update “books_statistics” table (see “Using Caching Views and Tables to Select Data” topic’s Task 1) every hour.
9. Create a stored procedure that is scheduled to optimize (compress) all database tables once per day.      

**05 - Using Stored Procedures to Manipulate Database Objects**

10. Create a stored procedure that automatically creates and populates with data “books_statistics” table (see “Using Caching Views and Tables to Select Data” topic’s Task 1).
11. Create a stored procedure that automatically creates and populates with data “tables_rc” table that contains all database tables names along with records count for each table.