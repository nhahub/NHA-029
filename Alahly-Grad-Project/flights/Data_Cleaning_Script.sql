use Flights ;

CREATE TABLE fact_flight_backup AS 
SELECT * FROM fact_flight;

-- Verify backup
SELECT 
    'Original' as table_name, 
    COUNT(*) as record_count 
FROM fact_flight
UNION ALL
SELECT 
    'Backup' as table_name, 
    COUNT(*) as record_count 
FROM fact_flight_backup;


-- Investigation 1: Are these cancelled or diverted flights?
SELECT 
    CASE 
        WHEN CANCELLED = '1' THEN 'Cancelled'
        WHEN DIVERTED = '1' THEN 'Diverted'
        ELSE 'Regular Flight'
    END as flight_status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / 486165, 2) as percentage_of_missing
FROM fact_flight
WHERE ORIGIN_AIRPORT_ID IS NULL OR DESTINATION_AIRPORT_ID IS NULL
GROUP BY flight_status
ORDER BY count DESC;

-- Investigation 2: Which airlines have missing airports?
SELECT 
    al.AIRLINE,
    al.IATA_CODE,
    COUNT(*) as flights_missing_airports,
    ROUND(COUNT(*) * 100.0 / 486165, 2) as percentage
FROM fact_flight f
LEFT JOIN dim_airline al ON f.AIRLINE_ID = al.AIRLINE_ID
WHERE f.ORIGIN_AIRPORT_ID IS NULL OR f.DESTINATION_AIRPORT_ID IS NULL
GROUP BY al.AIRLINE, al.IATA_CODE
ORDER BY flights_missing_airports DESC;

-- Investigation 3: Sample of records with missing airports
SELECT 
    FLIGHT_ID,
    FLIGHT_NUMBER,
    DATE_ID,
    AIRLINE_ID,
    SCHEDULED_DEPARTURE,
    CANCELLED,
    DIVERTED,
    CANCELLATION_ID
FROM fact_flight
WHERE ORIGIN_AIRPORT_ID IS NULL OR DESTINATION_AIRPORT_ID IS NULL
LIMIT 20;


				-- Before deletion statistics (for final documentation)
SELECT 
    'Before Cleaning' as status,
    COUNT(*) as total_records,
    SUM(CASE WHEN ORIGIN_AIRPORT_ID IS NULL OR DESTINATION_AIRPORT_ID IS NULL THEN 1 ELSE 0 END) as missing_airports,
    SUM(CASE WHEN ORIGIN_AIRPORT_ID IS NOT NULL AND DESTINATION_AIRPORT_ID IS NOT NULL THEN 1 ELSE 0 END) as valid_records,
    ROUND(SUM(CASE WHEN ORIGIN_AIRPORT_ID IS NULL OR DESTINATION_AIRPORT_ID IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as missing_percentage
FROM fact_flight;

-- DELETE records with missing airports
DELETE FROM fact_flight
WHERE ORIGIN_AIRPORT_ID IS NULL OR DESTINATION_AIRPORT_ID IS NULL;

-- Check how many rows were affected
SELECT ROW_COUNT() as rows_deleted;

-- Verify deletion
SELECT 
    'After Cleaning' as status,
    COUNT(*) as total_records,
    SUM(CASE WHEN ORIGIN_AIRPORT_ID IS NULL OR DESTINATION_AIRPORT_ID IS NULL THEN 1 ELSE 0 END) as missing_airports,
    ROUND(COUNT(*) * 100.0 / 5819079, 2) as retention_rate
FROM fact_flight;


-- Investigation 1: Find top duplicate patterns
SELECT 
    FLIGHT_NUMBER,
    DATE_ID,
    ORIGIN_AIRPORT_ID,
    DESTINATION_AIRPORT_ID,
    SCHEDULED_DEPARTURE,
    COUNT(*) as duplicate_count
FROM fact_flight
GROUP BY FLIGHT_NUMBER, DATE_ID, ORIGIN_AIRPORT_ID, DESTINATION_AIRPORT_ID, SCHEDULED_DEPARTURE
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- Investigation 2: Total duplicate count
-- Step 1: Create a new table with only unique records (keeping first occurrence)
CREATE TABLE fact_flight_cleaned AS
SELECT f.*
FROM fact_flight f
INNER JOIN (
    SELECT MIN(FLIGHT_ID) as keep_id
    FROM fact_flight
    GROUP BY FLIGHT_NUMBER, DATE_ID, ORIGIN_AIRPORT_ID, DESTINATION_AIRPORT_ID, SCHEDULED_DEPARTURE
) keep_list ON f.FLIGHT_ID = keep_list.keep_id;

-- This will take a few minutes but is more efficient than DELETE

-- Step 2: Check the new table
SELECT COUNT(*) as cleaned_record_count
FROM fact_flight_cleaned;

-- Step 3: Compare counts
SELECT 
    (SELECT COUNT(*) FROM fact_flight) as original_count,
    (SELECT COUNT(*) FROM fact_flight_cleaned) as cleaned_count,
    (SELECT COUNT(*) FROM fact_flight) - (SELECT COUNT(*) FROM fact_flight_cleaned) as duplicates_removed;

-- Step 4: Verify no duplicates remain in new table
SELECT COUNT(*) as remaining_duplicates
FROM (
    SELECT FLIGHT_NUMBER, DATE_ID, ORIGIN_AIRPORT_ID, DESTINATION_AIRPORT_ID, SCHEDULED_DEPARTURE, COUNT(*) as cnt
    FROM fact_flight_cleaned
    GROUP BY FLIGHT_NUMBER, DATE_ID, ORIGIN_AIRPORT_ID, DESTINATION_AIRPORT_ID, SCHEDULED_DEPARTURE
    HAVING COUNT(*) > 1
) duplicates;
-- Should return 0

-- Step 5: If everything looks good, replace the original table
-- ONLY RUN THESE AFTER VERIFYING THE ABOVE RESULTS!
-- DROP TABLE fact_flight;
-- RENAME TABLE fact_flight_cleaned TO fact_flight;


-- Check missing aircraft in the CLEANED table
SELECT 
    COUNT(*) as total_flights,
    SUM(CASE WHEN AIRCRAFT_ID IS NULL THEN 1 ELSE 0 END) as missing_aircraft,
    ROUND(SUM(CASE WHEN AIRCRAFT_ID IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 4) as percentage
FROM fact_flight_cleaned;


-- ========================================
-- FINAL VALIDATION - CLEANED DATA
-- ========================================

-- 1. Summary
SELECT 
    'Original Records' as metric,
    FORMAT(5819079, 0) as value
UNION ALL
SELECT 
    'After Removing Missing Airports',
    FORMAT(5332914, 0)
UNION ALL
SELECT 
    'After Removing Duplicates',
    FORMAT(COUNT(*), 0)
FROM fact_flight_cleaned
UNION ALL
SELECT 
    'Total Records Removed',
    FORMAT(5819079 - (SELECT COUNT(*) FROM fact_flight_cleaned), 0)
UNION ALL
SELECT 
    'Data Retention Rate',
    CONCAT(ROUND((SELECT COUNT(*) FROM fact_flight_cleaned) * 100.0 / 5819079, 2), '%');

-- 2. Critical Fields - No NULLs Check
SELECT 
    'DATE_ID Nulls' as check_item,
    COUNT(*) as count
FROM fact_flight_cleaned
WHERE DATE_ID IS NULL
UNION ALL
SELECT 'AIRLINE_ID Nulls', COUNT(*)
FROM fact_flight_cleaned
WHERE AIRLINE_ID IS NULL
UNION ALL
SELECT 'ORIGIN_AIRPORT_ID Nulls', COUNT(*)
FROM fact_flight_cleaned
WHERE ORIGIN_AIRPORT_ID IS NULL
UNION ALL
SELECT 'DESTINATION_AIRPORT_ID Nulls', COUNT(*)
FROM fact_flight_cleaned
WHERE DESTINATION_AIRPORT_ID IS NULL;
-- All should be 0

-- 3. No Duplicates Check
SELECT COUNT(*) as remaining_duplicates
FROM (
    SELECT FLIGHT_NUMBER, DATE_ID, ORIGIN_AIRPORT_ID, DESTINATION_AIRPORT_ID, SCHEDULED_DEPARTURE
    FROM fact_flight_cleaned
    GROUP BY FLIGHT_NUMBER, DATE_ID, ORIGIN_AIRPORT_ID, DESTINATION_AIRPORT_ID, SCHEDULED_DEPARTURE
    HAVING COUNT(*) > 1
) dup;
-- Should be 0

-- 4. Dataset Characteristics
SELECT 
    COUNT(*) as total_flights,
    COUNT(DISTINCT DATE_ID) as distinct_dates,
    COUNT(DISTINCT AIRLINE_ID) as distinct_airlines,
    COUNT(DISTINCT ORIGIN_AIRPORT_ID) as distinct_origins,
    COUNT(DISTINCT DESTINATION_AIRPORT_ID) as distinct_destinations,
    COUNT(DISTINCT AIRCRAFT_ID) as distinct_aircraft,
    SUM(CASE WHEN CANCELLED = '1' THEN 1 ELSE 0 END) as cancelled_flights,
    ROUND(SUM(CASE WHEN CANCELLED = '1' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as cancellation_rate
FROM fact_flight_cleaned;

-- 5. Test Sample Join (verify relationships work)
SELECT 
    f.FLIGHT_ID,
    f.FLIGHT_NUMBER,
    d.DATE_KEY as date,
    al.AIRLINE,
    o.CITY as origin,
    dest.CITY as destination,
    f.DEPARTURE_DELAY
FROM fact_flight_cleaned f
INNER JOIN dim_date d ON f.DATE_ID = d.DATE_ID
INNER JOIN dim_airline al ON f.AIRLINE_ID = al.AIRLINE_ID
INNER JOIN dim_airport o ON f.ORIGIN_AIRPORT_ID = o.AIRPORT_ID
INNER JOIN dim_airport dest ON f.DESTINATION_AIRPORT_ID = dest.AIRPORT_ID
LIMIT 5;
