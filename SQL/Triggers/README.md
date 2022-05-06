## Contents of sql files
### 01 - Using Triggers to Update Caching Tables and Fields
----------
1. Modify "subscribers" table to store the last visit date for each
subscriber (and keep that data up-to-date).   
2.  Create "averages" table to store the following up-to-date information:     
- average books count for "taken by a subscriber";     
- average days count for "a subscriber keeps a book";      
- average books count for "returned by a subscriber".     
### 02 - Using Triggers to Ensure Data Consistency
3. Modify "subscribers" table to store the number of books taken by each subscriber (and keep that data up-to-date).        
4. Modify "genres" table to store the number of books in each genre (and keep that data up-to-date).     
### 03 - Using Triggers to Control Data Modification    
5. Create a trigger to prevent the following situations with subscriptions:
- subscription start date is in the future;
- subscription end date is in the past (for INSERT operations only);
- subscription end date is less than subscription start date.   
6. Create a trigger to prevent creation of a new subscription for a
subscriber already having 10 (and more) books taken.
7. Create a trigger to prevent modifying a subscription from
inactive state back to active (i.e. from modifying "sb_is_active"
field value from “N” to “Y”).
### 04 - Using Triggers to Control Data Format and Values 
8. Create a trigger to only allow registration of subscribers with a dot and at least two words in their names.
9. Create a trigger to only allow registration of books issued no
more than 100 years ago.
### 05 - Using Triggers to Correct Data On-the-Fly
10. Create a trigger to check if there is a dot at the end of
subscriber’s name and to add a such dot if there is no one.
11. Create a trigger to change the subscription end date to "current
date + two months" if the given end date is in the past or is less than the start date.
