use flights;

-- ============================================================================
-- VIEW 1: vw_flight_performance_master
-- Purpose: Complete flight performance data with all dimensions
-- Use: Base view for all analyses
-- ============================================================================

CREATE OR REPLACE VIEW vw_flight_performance_master AS
SELECT 
    -- Flight Identifiers
    f.FLIGHT_ID,
    f.FLIGHT_NUMBER,
    
    -- Date Dimensions
    f.DATE_ID,
    d.DATE_KEY as flight_date,
    d.YEAR as flight_year,
    d.MONTH as flight_month,
    d.DAY as flight_day,
    d.DAY_OF_WEEK,
    CASE 
        WHEN d.MONTH IN (12, 1, 2) THEN 'Winter'
        WHEN d.MONTH IN (3, 4, 5) THEN 'Spring'
        WHEN d.MONTH IN (6, 7, 8) THEN 'Summer'
        ELSE 'Fall'
    END as season,
    
    -- Airline Dimensions
    al.AIRLINE_ID,
    al.AIRLINE as airline_name,
    al.IATA_CODE as airline_code,
    
    -- Airport Dimensions (Origin)
    f.ORIGIN_AIRPORT_ID,
    o.AIRPORT as origin_airport,
    o.IATA_CODE as origin_code,
    o.CITY as origin_city,
    o.STATE as origin_state,
    o.LATITUDE as origin_lat,
    o.LONGITUDE as origin_long,
    
    -- Airport Dimensions (Destination)
    f.DESTINATION_AIRPORT_ID,
    dest.AIRPORT as destination_airport,
    dest.IATA_CODE as destination_code,
    dest.CITY as destination_city,
    dest.STATE as destination_state,
    dest.LATITUDE as dest_lat,
    dest.LONGITUDE as dest_long,
    
    -- Route Information
    CONCAT(o.CITY, ' → ', dest.CITY) as route_name,
    CONCAT(o.IATA_CODE, '-', dest.IATA_CODE) as route_code,
    
    -- Aircraft Dimensions
    f.AIRCRAFT_ID,
    ac.TAIL_NUMBER,
    
    -- Time Information
    f.SCHEDULED_DEPARTURE,
    CAST(SUBSTRING(f.SCHEDULED_DEPARTURE, 1, 2) AS UNSIGNED) as departure_hour,
    CASE 
        WHEN CAST(SUBSTRING(f.SCHEDULED_DEPARTURE, 1, 2) AS UNSIGNED) BETWEEN 5 AND 8 THEN 'Early Morning (5-8 AM)'
        WHEN CAST(SUBSTRING(f.SCHEDULED_DEPARTURE, 1, 2) AS UNSIGNED) BETWEEN 9 AND 11 THEN 'Mid Morning (9-11 AM)'
        WHEN CAST(SUBSTRING(f.SCHEDULED_DEPARTURE, 1, 2) AS UNSIGNED) BETWEEN 12 AND 14 THEN 'Midday (12-2 PM)'
        WHEN CAST(SUBSTRING(f.SCHEDULED_DEPARTURE, 1, 2) AS UNSIGNED) BETWEEN 15 AND 17 THEN 'Afternoon (3-5 PM)'
        WHEN CAST(SUBSTRING(f.SCHEDULED_DEPARTURE, 1, 2) AS UNSIGNED) BETWEEN 18 AND 20 THEN 'Evening (6-8 PM)'
        ELSE 'Night (9 PM-4 AM)'
    END as time_of_day,
    
    f.DEPARTURE_TIME,
    f.SCHEDULED_ARRIVAL,
    f.ARRIVAL_TIME,
    
    -- Delay Metrics (converted to numeric)
    CAST(f.DEPARTURE_DELAY AS SIGNED) as departure_delay_min,
    CAST(f.ARRIVAL_DELAY AS SIGNED) as arrival_delay_min,
    
    -- On-Time Performance Flags (15-minute threshold)
    CASE WHEN CAST(f.DEPARTURE_DELAY AS SIGNED) <= 15 THEN 1 ELSE 0 END as is_on_time_departure,
    CASE WHEN CAST(f.ARRIVAL_DELAY AS SIGNED) <= 15 THEN 1 ELSE 0 END as is_on_time_arrival,
    
    -- Delay Categories
    CASE 
        WHEN CAST(f.DEPARTURE_DELAY AS SIGNED) <= 0 THEN 'Early/On-Time'
        WHEN CAST(f.DEPARTURE_DELAY AS SIGNED) BETWEEN 1 AND 15 THEN 'Minor Delay (1-15 min)'
        WHEN CAST(f.DEPARTURE_DELAY AS SIGNED) BETWEEN 16 AND 30 THEN 'Moderate Delay (16-30 min)'
        WHEN CAST(f.DEPARTURE_DELAY AS SIGNED) BETWEEN 31 AND 60 THEN 'Significant Delay (31-60 min)'
        ELSE 'Major Delay (>60 min)'
    END as departure_delay_category,
    
    CASE 
        WHEN CAST(f.ARRIVAL_DELAY AS SIGNED) <= 0 THEN 'Early/On-Time'
        WHEN CAST(f.ARRIVAL_DELAY AS SIGNED) BETWEEN 1 AND 15 THEN 'Minor Delay (1-15 min)'
        WHEN CAST(f.ARRIVAL_DELAY AS SIGNED) BETWEEN 16 AND 30 THEN 'Moderate Delay (16-30 min)'
        WHEN CAST(f.ARRIVAL_DELAY AS SIGNED) BETWEEN 31 AND 60 THEN 'Significant Delay (31-60 min)'
        ELSE 'Major Delay (>60 min)'
    END as arrival_delay_category,
    
    -- Time Metrics
    CAST(f.SCHEDULED_TIME AS SIGNED) as scheduled_time_min,
    CAST(f.ELAPSED_TIME AS SIGNED) as elapsed_time_min,
    CAST(f.AIR_TIME AS SIGNED) as air_time_min,
    CAST(f.DISTANCE AS SIGNED) as distance_miles,
    
    -- Operational Status
    f.CANCELLED,
    f.DIVERTED,
    CASE WHEN f.CANCELLED = '1' THEN 1 ELSE 0 END as is_cancelled,
    CASE WHEN f.DIVERTED = '1' THEN 1 ELSE 0 END as is_diverted,
    
    -- Cancellation Information
    f.CANCELLATION_ID,
    cc.CANCELLATION_REASON,
    cc.CANCELLATION_DESCRIPTION,
    
    -- Delay Breakdown (if available)
    CAST(f.AIR_SYSTEM_DELAY AS SIGNED) as air_system_delay_min,
    CAST(f.SECURITY_DELAY AS SIGNED) as security_delay_min,
    CAST(f.AIRLINE_DELAY AS SIGNED) as airline_delay_min,
    CAST(f.LATE_AIRCRAFT_DELAY AS SIGNED) as late_aircraft_delay_min,
    CAST(f.WEATHER_DELAY AS SIGNED) as weather_delay_min

FROM fact_flight_cleaned f
INNER JOIN dim_date d ON f.DATE_ID = d.DATE_ID
INNER JOIN dim_airline al ON f.AIRLINE_ID = al.AIRLINE_ID
INNER JOIN dim_airport o ON f.ORIGIN_AIRPORT_ID = o.AIRPORT_ID
INNER JOIN dim_airport dest ON f.DESTINATION_AIRPORT_ID = dest.AIRPORT_ID
LEFT JOIN dim_aircraft ac ON f.AIRCRAFT_ID = ac.AIRCRAFT_ID
LEFT JOIN dim_cancellation_code cc ON f.CANCELLATION_ID = cc.CANCELLATION_ID;


select * from vw_flight_performance_master limit 100;



-- ============================================================================
-- VIEW 2: vw_airline_performance_summary
-- Purpose: Aggregated airline performance metrics
-- Use: Analysis 1 - Airline Comparison
-- ============================================================================

CREATE OR REPLACE VIEW vw_airline_performance_summary AS
SELECT 
    airline_code,
    airline_name,
    
    -- Volume Metrics
    COUNT(*) as total_flights,
    SUM(is_cancelled) as total_cancellations,
    SUM(is_diverted) as total_diversions,
    
    -- On-Time Performance
    ROUND(SUM(is_on_time_departure) * 100.0 / COUNT(*), 2) as on_time_departure_rate,
    ROUND(SUM(is_on_time_arrival) * 100.0 / COUNT(*), 2) as on_time_arrival_rate,
    
    -- Average Delays
    ROUND(AVG(departure_delay_min), 2) as avg_departure_delay,
    ROUND(AVG(arrival_delay_min), 2) as avg_arrival_delay,
    
    -- Median Delays
    ROUND(AVG(CASE WHEN departure_delay_min > 0 THEN departure_delay_min END), 2) as avg_positive_dep_delay,
    ROUND(AVG(CASE WHEN arrival_delay_min > 0 THEN arrival_delay_min END), 2) as avg_positive_arr_delay,
    
    -- Delay Distribution
    ROUND(SUM(CASE WHEN departure_delay_min <= 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as pct_early_ontime,
    ROUND(SUM(CASE WHEN departure_delay_min BETWEEN 1 AND 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as pct_minor_delay,
    ROUND(SUM(CASE WHEN departure_delay_min BETWEEN 16 AND 30 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as pct_moderate_delay,
    ROUND(SUM(CASE WHEN departure_delay_min > 30 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as pct_major_delay,
    
    -- Cancellation Rate
    ROUND(SUM(is_cancelled) * 100.0 / COUNT(*), 2) as cancellation_rate,
    
    -- Operational Efficiency
    ROUND(AVG(air_time_min), 2) as avg_air_time,
    ROUND(AVG(distance_miles), 2) as avg_distance,
    ROUND(AVG(distance_miles) / NULLIF(AVG(air_time_min), 0) * 60, 2) as avg_speed_mph,
    
    -- Schedule Reliability (std deviation)
    ROUND(STDDEV(departure_delay_min), 2) as departure_delay_stddev,
    ROUND(STDDEV(arrival_delay_min), 2) as arrival_delay_stddev

FROM vw_flight_performance_master
GROUP BY airline_code, airline_name;

select * from vw_airline_performance_summary limit 10;



-- ============================================================================
-- VIEW 3: vw_time_pattern_analysis
-- Purpose: Delay patterns by time of day and day of week
-- Use: Analysis 2 - Time Pattern Analysis
-- ============================================================================

CREATE OR REPLACE VIEW vw_time_pattern_analysis AS
SELECT 
    departure_hour,
    time_of_day,
    DAY_OF_WEEK,
    
    -- Volume
    COUNT(*) as flights,
    
    -- Performance Metrics
    ROUND(AVG(departure_delay_min), 2) as avg_departure_delay,
    ROUND(AVG(arrival_delay_min), 2) as avg_arrival_delay,
    ROUND(SUM(is_on_time_departure) * 100.0 / COUNT(*), 2) as on_time_departure_rate,
    ROUND(SUM(is_on_time_arrival) * 100.0 / COUNT(*), 2) as on_time_arrival_rate,
    
    -- Delay Severity
    ROUND(SUM(CASE WHEN departure_delay_min > 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as delayed_percentage,
    ROUND(SUM(CASE WHEN departure_delay_min > 60 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as severely_delayed_pct,
    
    -- Cancellations
    SUM(is_cancelled) as cancellations,
    ROUND(SUM(is_cancelled) * 100.0 / COUNT(*), 2) as cancellation_rate

FROM vw_flight_performance_master
GROUP BY departure_hour, time_of_day, DAY_OF_WEEK;


select * from vw_time_pattern_analysis ;



-- ============================================================================
-- VIEW 4: vw_seasonal_trends_analysis
-- Purpose: Monthly and seasonal performance trends
-- Use: Analysis 3 - Seasonal Analysis
-- ============================================================================

CREATE OR REPLACE VIEW vw_seasonal_trends_analysis AS
SELECT 
    flight_year,
    flight_month,
    season,
    
    -- Volume Metrics
    COUNT(*) as total_flights,
    COUNT(DISTINCT flight_date) as operating_days,
    ROUND(COUNT(*) / COUNT(DISTINCT flight_date), 2) as avg_daily_flights,
    
    -- Performance Metrics
    ROUND(AVG(departure_delay_min), 2) as avg_departure_delay,
    ROUND(AVG(arrival_delay_min), 2) as avg_arrival_delay,
    ROUND(SUM(is_on_time_departure) * 100.0 / COUNT(*), 2) as on_time_departure_rate,
    ROUND(SUM(is_on_time_arrival) * 100.0 / COUNT(*), 2) as on_time_arrival_rate,
    
    -- Cancellations & Diversions
    SUM(is_cancelled) as total_cancellations,
    SUM(is_diverted) as total_diversions,
    ROUND(SUM(is_cancelled) * 100.0 / COUNT(*), 2) as cancellation_rate,
    
    -- Delay Causes (monthly breakdown)
    ROUND(AVG(weather_delay_min), 2) as avg_weather_delay,
    ROUND(AVG(air_system_delay_min), 2) as avg_air_system_delay,
    ROUND(AVG(security_delay_min), 2) as avg_security_delay,
    ROUND(AVG(airline_delay_min), 2) as avg_airline_delay,
    ROUND(AVG(late_aircraft_delay_min), 2) as avg_late_aircraft_delay,
    
    -- Operational Efficiency
    ROUND(AVG(air_time_min), 2) as avg_air_time,
    ROUND(AVG(elapsed_time_min), 2) as avg_elapsed_time

FROM vw_flight_performance_master
GROUP BY flight_year, flight_month, season;


select * from vw_seasonal_trends_analysis;



-- ============================================================================
-- VIEW 5: vw_route_performance_analysis
-- Purpose: Performance metrics by route
-- Use: Analysis 4 - Route Analysis
-- ============================================================================

CREATE OR REPLACE VIEW vw_route_performance_analysis AS
SELECT 
    route_code,
    route_name,
    origin_code,
    origin_city,
    origin_state,
    destination_code,
    destination_city,
    destination_state,
    
    -- Geographic coordinates for mapping
    origin_lat,
    origin_long,
    dest_lat,
    dest_long,
    
    -- Volume Metrics
    COUNT(*) as total_flights,
    COUNT(DISTINCT airline_code) as airlines_serving,
    ROUND(COUNT(*) / 365.0, 2) as avg_daily_flights,
    
    -- Performance Metrics
    ROUND(AVG(departure_delay_min), 2) as avg_departure_delay,
    ROUND(AVG(arrival_delay_min), 2) as avg_arrival_delay,
    ROUND(SUM(is_on_time_departure) * 100.0 / COUNT(*), 2) as on_time_departure_rate,
    ROUND(SUM(is_on_time_arrival) * 100.0 / COUNT(*), 2) as on_time_arrival_rate,
    
    -- Reliability Metrics
    ROUND(STDDEV(departure_delay_min), 2) as departure_delay_variance,
    ROUND(STDDEV(arrival_delay_min), 2) as arrival_delay_variance,
    
    -- Route Characteristics
    ROUND(AVG(distance_miles), 2) as avg_distance,
    ROUND(AVG(air_time_min), 2) as avg_air_time,
    ROUND(AVG(scheduled_time_min), 2) as avg_scheduled_time,
    
    -- Cancellation Rate
    SUM(is_cancelled) as cancellations,
    ROUND(SUM(is_cancelled) * 100.0 / COUNT(*), 2) as cancellation_rate,
    
    -- Delay Categories
    ROUND(SUM(CASE WHEN departure_delay_min > 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as delayed_percentage,
    ROUND(SUM(CASE WHEN departure_delay_min > 60 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as severely_delayed_pct

FROM vw_flight_performance_master
GROUP BY route_code, route_name, origin_code, origin_city, origin_state,
         destination_code, destination_city, destination_state,
         origin_lat, origin_long, dest_lat, dest_long
HAVING total_flights >= 50;  -- Filter routes with sufficient data


select * from vw_route_performance_analysis ;


-- ============================================================================
-- VIEW 6: vw_airport_bottleneck_analysis
-- Purpose: Airport performance and congestion metrics
-- Use: Analysis 5 - Airport Bottleneck Identification
-- ============================================================================

CREATE OR REPLACE VIEW vw_airport_bottleneck_analysis AS
SELECT 
    airport_code,
    airport_name,
    city,
    state,
    direction,  -- 'Departure' or 'Arrival'
    
    -- Volume Metrics
    total_flights,
    avg_daily_flights,
    
    -- Performance Metrics
    avg_delay,
    on_time_rate,
    delayed_percentage,
    severely_delayed_pct,
    
    -- Cancellations
    cancellations,
    cancellation_rate,
    
    -- Delay Variance (reliability indicator)
    delay_stddev,
    
    -- Bottleneck Score (higher = worse bottleneck)
    ROUND((avg_delay * 0.4) + (delayed_percentage * 0.3) + (cancellation_rate * 0.3), 2) as bottleneck_score

FROM (
    -- Departure Performance
    SELECT 
        origin_code as airport_code,
        origin_airport as airport_name,
        origin_city as city,
        origin_state as state,
        'Departure' as direction,
        COUNT(*) as total_flights,
        ROUND(COUNT(*) / 365.0, 2) as avg_daily_flights,
        ROUND(AVG(departure_delay_min), 2) as avg_delay,
        ROUND(SUM(is_on_time_departure) * 100.0 / COUNT(*), 2) as on_time_rate,
        ROUND(SUM(CASE WHEN departure_delay_min > 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as delayed_percentage,
        ROUND(SUM(CASE WHEN departure_delay_min > 60 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as severely_delayed_pct,
        SUM(is_cancelled) as cancellations,
        ROUND(SUM(is_cancelled) * 100.0 / COUNT(*), 2) as cancellation_rate,
        ROUND(STDDEV(departure_delay_min), 2) as delay_stddev
    FROM vw_flight_performance_master
    GROUP BY origin_code, origin_airport, origin_city, origin_state
    
    UNION ALL
    
    -- Arrival Performance
    SELECT 
        destination_code as airport_code,
        destination_airport as airport_name,
        destination_city as city,
        destination_state as state,
        'Arrival' as direction,
        COUNT(*) as total_flights,
        ROUND(COUNT(*) / 365.0, 2) as avg_daily_flights,
        ROUND(AVG(arrival_delay_min), 2) as avg_delay,
        ROUND(SUM(is_on_time_arrival) * 100.0 / COUNT(*), 2) as on_time_rate,
        ROUND(SUM(CASE WHEN arrival_delay_min > 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as delayed_percentage,
        ROUND(SUM(CASE WHEN arrival_delay_min > 60 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as severely_delayed_pct,
        SUM(is_cancelled) as cancellations,
        ROUND(SUM(is_cancelled) * 100.0 / COUNT(*), 2) as cancellation_rate,
        ROUND(STDDEV(arrival_delay_min), 2) as delay_stddev
    FROM vw_flight_performance_master
    GROUP BY destination_code, destination_airport, destination_city, destination_state
) airport_metrics;


SELECT 
    *
FROM
    vw_airport_bottleneck_analysis;