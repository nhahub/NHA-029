use flights;

-- View 1: On-Time Departure Rate
CREATE OR REPLACE VIEW v_on_time_departure_rate AS
SELECT 
    a.AIRLINE,
    COUNT(*) AS total_flights,
    SUM(CASE WHEN f.DEPARTURE_DELAY <= 15 THEN 1 ELSE 0 END) AS on_time_departures,
    ROUND(SUM(CASE WHEN f.DEPARTURE_DELAY <= 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS on_time_departure_rate
FROM fact_flight f
JOIN dim_airline a ON f.AIRLINE_ID = a.AIRLINE_ID
GROUP BY a.AIRLINE;

select * from v_on_time_departure_rate;


-- View 2: On-Time Arrival Rate
CREATE OR REPLACE VIEW v_on_time_arrival_rate AS
SELECT 
    a.AIRLINE,
    COUNT(*) AS total_flights,
    SUM(CASE WHEN f.ARRIVAL_DELAY <= 15 THEN 1 ELSE 0 END) AS on_time_arrivals,
    ROUND(SUM(CASE WHEN f.ARRIVAL_DELAY <= 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS on_time_arrival_rate
FROM fact_flight f
JOIN dim_airline a ON f.AIRLINE_ID = a.AIRLINE_ID
GROUP BY a.AIRLINE;


select * from v_on_time_arrival_rate;


-- View 3: Average Departure Delay
CREATE OR REPLACE VIEW v_avg_departure_delay AS
SELECT 
    a.AIRLINE,
    ROUND(AVG(f.DEPARTURE_DELAY), 2) AS avg_departure_delay
FROM fact_flight f
JOIN dim_airline a ON f.AIRLINE_ID = a.AIRLINE_ID
GROUP BY a.AIRLINE;


select * from v_avg_departure_delay;


-- View 4: Average Arrival Delay
CREATE OR REPLACE VIEW v_avg_arrival_delay AS
SELECT 
    a.AIRLINE,
    ROUND(AVG(f.ARRIVAL_DELAY), 2) AS avg_arrival_delay
FROM fact_flight f
JOIN dim_airline a ON f.AIRLINE_ID = a.AIRLINE_ID
GROUP BY a.AIRLINE;


select * from v_avg_arrival_delay;


-- View 5: Delay Distribution (%)
CREATE OR REPLACE VIEW v_delay_distribution AS
SELECT 
    a.AIRLINE,
    ROUND(SUM(CASE WHEN f.ARRIVAL_DELAY BETWEEN 0 AND 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS minor_delays_pct,
    ROUND(SUM(CASE WHEN f.ARRIVAL_DELAY BETWEEN 16 AND 60 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS moderate_delays_pct,
    ROUND(SUM(CASE WHEN f.ARRIVAL_DELAY > 60 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS severe_delays_pct
FROM fact_flight f
JOIN dim_airline a ON f.AIRLINE_ID = a.AIRLINE_ID
GROUP BY a.AIRLINE;

select * from v_delay_distribution;


-- View 6: Schedule Reliability Index
CREATE OR REPLACE VIEW v_schedule_reliability_index AS
SELECT 
    a.AIRLINE,
    ROUND((SUM(CASE WHEN f.DEPARTURE_DELAY <= 15 THEN 1 ELSE 0 END) + SUM(CASE WHEN f.ARRIVAL_DELAY <= 15 THEN 1 ELSE 0 END)) * 100.0 / (2 * COUNT(*)), 2) AS schedule_reliability_index
FROM fact_flight f
JOIN dim_airline a ON f.AIRLINE_ID = a.AIRLINE_ID
GROUP BY a.AIRLINE;


select * from v_schedule_reliability_index;


-- View 7: Monthly Performance Trends
CREATE OR REPLACE VIEW v_monthly_performance_trends AS
SELECT 
    d.YEAR,
    d.MONTH,
    a.AIRLINE,
    ROUND(AVG(f.ARRIVAL_DELAY), 2) AS avg_arrival_delay,
    ROUND(AVG(f.DEPARTURE_DELAY), 2) AS avg_departure_delay,
    ROUND(SUM(CASE WHEN f.CANCELLED = '1' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate
FROM fact_flight f
JOIN dim_date d ON f.DATE_ID = d.DATE_ID
JOIN dim_airline a ON f.AIRLINE_ID = a.AIRLINE_ID
GROUP BY d.YEAR, d.MONTH, a.AIRLINE
ORDER BY d.YEAR, d.MONTH;


select * from v_monthly_performance_trends;


-- View 8: Cancellation Rate
CREATE OR REPLACE VIEW v_cancellation_rate AS
    SELECT 
        a.AIRLINE,
        COUNT(*) AS total_flights,
        SUM(CASE
            WHEN f.CANCELLED = '1' THEN 1
            ELSE 0
        END) AS cancelled_flights,
        ROUND(SUM(CASE
                    WHEN f.CANCELLED = '1' THEN 1
                    ELSE 0
                END) * 100.0 / COUNT(*),
                2) AS cancellation_rate
    FROM
        fact_flight f
            JOIN
        dim_airline a ON f.AIRLINE_ID = a.AIRLINE_ID
    GROUP BY a.AIRLINE;

select * from v_cancellation_rate;