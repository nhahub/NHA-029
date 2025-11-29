use flights;

select * from dim_airline;

-- Test 1: Check DATE_ID references
SELECT 'Invalid DATE_ID' as issue, COUNT(*) as count
FROM fact_flight f
LEFT JOIN dim_date d ON f.DATE_ID = d.DATE_ID
WHERE d.DATE_ID IS NULL AND f.DATE_ID IS NOT NULL;

-- Test 2: Check AIRLINE_ID references
SELECT 'Invalid AIRLINE_ID' as issue, COUNT(*) as count
FROM fact_flight f
LEFT JOIN dim_airline a ON f.AIRLINE_ID = a.AIRLINE_ID
WHERE a.AIRLINE_ID IS NULL AND f.AIRLINE_ID IS NOT NULL;

-- Test 3: Check AIRCRAFT_ID references
SELECT 'Invalid AIRCRAFT_ID' as issue, COUNT(*) as count
FROM fact_flight f
LEFT JOIN dim_aircraft ac ON f.AIRCRAFT_ID = ac.AIRCRAFT_ID
WHERE ac.AIRCRAFT_ID IS NULL AND f.AIRCRAFT_ID IS NOT NULL;

-- Test 4: Check ORIGIN_AIRPORT_ID references
SELECT 'Invalid ORIGIN_AIRPORT_ID' as issue, COUNT(*) as count
FROM fact_flight f
LEFT JOIN dim_airport o ON f.ORIGIN_AIRPORT_ID = o.AIRPORT_ID
WHERE o.AIRPORT_ID IS NULL AND f.ORIGIN_AIRPORT_ID IS NOT NULL;

-- Test 5: Check DESTINATION_AIRPORT_ID references
SELECT 'Invalid DESTINATION_AIRPORT_ID' as issue, COUNT(*) as count
FROM fact_flight f
LEFT JOIN dim_airport d ON f.DESTINATION_AIRPORT_ID = d.AIRPORT_ID
WHERE d.AIRPORT_ID IS NULL AND f.DESTINATION_AIRPORT_ID IS NOT NULL;

-- Test 6: Check CANCELLATION_ID references
SELECT 'Invalid CANCELLATION_ID' as issue, COUNT(*) as count
FROM fact_flight f
LEFT JOIN dim_cancellation_code c ON f.CANCELLATION_ID = c.CANCELLATION_ID
WHERE c.CANCELLATION_ID IS NULL AND f.CANCELLATION_ID IS NOT NULL;


-- Comprehensive relationship test
SELECT 
    'Total Flights' as metric,
    COUNT(*) as count
FROM fact_flight
UNION ALL
SELECT 
    'Flights with Valid Date',
    COUNT(*)
FROM fact_flight f
INNER JOIN dim_date d ON f.DATE_ID = d.DATE_ID
UNION ALL
SELECT 
    'Flights with Valid Airline',
    COUNT(*)
FROM fact_flight f
INNER JOIN dim_airline a ON f.AIRLINE_ID = a.AIRLINE_ID
UNION ALL
SELECT 
    'Flights with Valid Aircraft',
    COUNT(*)
FROM fact_flight f
INNER JOIN dim_aircraft ac ON f.AIRCRAFT_ID = ac.AIRCRAFT_ID
UNION ALL
SELECT 
    'Flights with Valid Origin Airport',
    COUNT(*)
FROM fact_flight f
INNER JOIN dim_airport o ON f.ORIGIN_AIRPORT_ID = o.AIRPORT_ID
UNION ALL
SELECT 
    'Flights with Valid Destination Airport',
    COUNT(*)
FROM fact_flight f
INNER JOIN dim_airport d ON f.DESTINATION_AIRPORT_ID = d.AIRPORT_ID
UNION ALL
SELECT 
    'Flights with Valid Cancellation Code',
    COUNT(*)
FROM fact_flight f
INNER JOIN dim_cancellation_code c ON f.CANCELLATION_ID = c.CANCELLATION_ID;


-- Test a complete join across all dimensions (first 10 flights)
SELECT 
    f.FLIGHT_ID,
    f.FLIGHT_NUMBER,
    d.DATE_KEY as flight_date,
    d.DAY_OF_WEEK,
    al.AIRLINE as airline_name,
    al.IATA_CODE as airline_code,
    o.AIRPORT as origin_airport,
    o.CITY as origin_city,
    dest.AIRPORT as destination_airport,
    dest.CITY as destination_city,
    ac.TAIL_NUMBER as aircraft,
    f.SCHEDULED_DEPARTURE,
    f.DEPARTURE_DELAY,
    f.ARRIVAL_DELAY,
    CASE WHEN f.CANCELLED = '1' THEN cc.CANCELLATION_REASON ELSE 'Not Cancelled' END as cancellation_status
FROM fact_flight f
INNER JOIN dim_date d ON f.DATE_ID = d.DATE_ID
INNER JOIN dim_airline al ON f.AIRLINE_ID = al.AIRLINE_ID
INNER JOIN dim_aircraft ac ON f.AIRCRAFT_ID = ac.AIRCRAFT_ID
INNER JOIN dim_airport o ON f.ORIGIN_AIRPORT_ID = o.AIRPORT_ID
INNER JOIN dim_airport dest ON f.DESTINATION_AIRPORT_ID = dest.AIRPORT_ID
LEFT JOIN dim_cancellation_code cc ON f.CANCELLATION_ID = cc.CANCELLATION_ID
LIMIT 10;


-- Check for NULLs in fact table
SELECT 
    'DATE_ID' as field,
    COUNT(*) as null_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_flight), 2) as null_percentage
FROM fact_flight
WHERE DATE_ID IS NULL
UNION ALL
SELECT 'AIRLINE_ID', COUNT(*), ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_flight), 2)
FROM fact_flight WHERE AIRLINE_ID IS NULL
UNION ALL
SELECT 'AIRCRAFT_ID', COUNT(*), ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_flight), 2)
FROM fact_flight WHERE AIRCRAFT_ID IS NULL
UNION ALL
SELECT 'ORIGIN_AIRPORT_ID', COUNT(*), ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_flight), 2)
FROM fact_flight WHERE ORIGIN_AIRPORT_ID IS NULL
UNION ALL
SELECT 'DESTINATION_AIRPORT_ID', COUNT(*), ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_flight), 2)
FROM fact_flight WHERE DESTINATION_AIRPORT_ID IS NULL
UNION ALL
SELECT 'FLIGHT_NUMBER', COUNT(*), ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_flight), 2)
FROM fact_flight WHERE FLIGHT_NUMBER IS NULL
UNION ALL
SELECT 'SCHEDULED_DEPARTURE', COUNT(*), ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_flight), 2)
FROM fact_flight WHERE SCHEDULED_DEPARTURE IS NULL
UNION ALL
SELECT 'DEPARTURE_DELAY', COUNT(*), ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_flight), 2)
FROM fact_flight WHERE DEPARTURE_DELAY IS NULL;


-- Check for duplicate flights (same flight number, date, origin, destination)
SELECT 
    FLIGHT_NUMBER,
    DATE_ID,
    ORIGIN_AIRPORT_ID,
    DESTINATION_AIRPORT_ID,
    COUNT(*) as duplicate_count
FROM fact_flight
GROUP BY FLIGHT_NUMBER, DATE_ID, ORIGIN_AIRPORT_ID, DESTINATION_AIRPORT_ID
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


-- Check for negative delays (unusual but possible)
SELECT 
    'Negative Departure Delays' as issue,
    COUNT(*) as count
FROM fact_flight
WHERE CAST(DEPARTURE_DELAY AS SIGNED) < -60  -- More than 60 minutes early
UNION ALL
SELECT 
    'Negative Arrival Delays',
    COUNT(*)
FROM fact_flight
WHERE CAST(ARRIVAL_DELAY AS SIGNED) < -60
UNION ALL
SELECT 
    'Extreme Delays (>500 min)',
    COUNT(*)
FROM fact_flight
WHERE CAST(DEPARTURE_DELAY AS SIGNED) > 500 OR CAST(ARRIVAL_DELAY AS SIGNED) > 500
UNION ALL
SELECT 
    'Same Origin and Destination',
    COUNT(*)
FROM fact_flight
WHERE ORIGIN_AIRPORT_ID = DESTINATION_AIRPORT_ID
UNION ALL
SELECT 
    'Negative Distance',
    COUNT(*)
FROM fact_flight
WHERE CAST(DISTANCE AS SIGNED) <= 0;


-- Check dim_date completeness
SELECT 
    MIN(DATE_KEY) as earliest_date,
    MAX(DATE_KEY) as latest_date,
    COUNT(*) as total_dates,
    COUNT(DISTINCT YEAR) as years_covered
FROM dim_date;

-- Check for missing airports
SELECT 
    'Airports without City' as issue,
    COUNT(*) as count
FROM dim_airport
WHERE CITY IS NULL OR CITY = ''
UNION ALL
SELECT 
    'Airports without State',
    COUNT(*)
FROM dim_airport
WHERE STATE IS NULL OR STATE = ''
UNION ALL
SELECT 
    'Airports without Country',
    COUNT(*)
FROM dim_airport
WHERE COUNTRY IS NULL OR COUNTRY = '';

-- Check airlines
SELECT 
    'Airlines without IATA Code' as issue,
    COUNT(*) as count
FROM dim_airline
WHERE IATA_CODE IS NULL OR IATA_CODE = ''
UNION ALL
SELECT 
    'Airlines without Name',
    COUNT(*)
FROM dim_airline
WHERE AIRLINE IS NULL OR AIRLINE = '';



-- Check data ranges and distributions
SELECT 
    COUNT(*) as total_flights,
    COUNT(DISTINCT DATE_ID) as distinct_dates,
    COUNT(DISTINCT AIRLINE_ID) as distinct_airlines,
    COUNT(DISTINCT ORIGIN_AIRPORT_ID) as distinct_origins,
    COUNT(DISTINCT DESTINATION_AIRPORT_ID) as distinct_destinations,
    COUNT(DISTINCT AIRCRAFT_ID) as distinct_aircraft,
    SUM(CASE WHEN CANCELLED = '1' THEN 1 ELSE 0 END) as cancelled_flights,
    ROUND(SUM(CASE WHEN CANCELLED = '1' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as cancellation_rate
FROM fact_flight;

