DELETE FROM actors_history_scd
WHERE current_year = (SELECT MAX(current_year) FROM actors);

WITH parameters AS (
    SELECT MAX(current_year) AS target_year FROM actors
),
actor_history AS (
SELECT
    actorid,
    quality_class,
    is_active,
    current_year,
    LAG(quality_class) OVER (
        PARTITION BY actorid ORDER BY current_year
    ) AS previous_quality_class,
    LAG(is_active) OVER (
        PARTITION BY actorid ORDER BY current_year
    ) AS previous_is_active
FROM actors
WHERE current_year <= (SELECT target_year FROM parameters)
),
change_indicators AS (
SELECT
    actorid,
    quality_class,
    is_active,
    current_year,
    CASE
        WHEN previous_quality_class IS NULL THEN 1
        WHEN quality_class IS DISTINCT FROM previous_quality_class THEN 1
        WHEN is_active IS DISTINCT FROM previous_is_active THEN 1
        ELSE 0
    END AS changed
FROM actor_history
),
streaks AS (
SELECT
    actorid,
    quality_class,
    is_active,
    current_year,
    SUM(changed) OVER (
        PARTITION BY actorid
        ORDER BY current_year
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS streak_id
FROM change_indicators
),
compressed_history AS (
    SELECT
        actorid,
        quality_class,
        is_active,
        MIN(current_year) AS start_date,
        MAX(current_year) AS end_date
    FROM streaks
    GROUP BY actorid, streak_id, quality_class, is_active
)
INSERT INTO actors_history_scd (
    actorid, quality_class, is_active, start_date, end_date, current_year
)
SELECT
actorid,
quality_class,
is_active,
start_date,
end_date,
(SELECT target_year FROM parameters)
FROM compressed_history;