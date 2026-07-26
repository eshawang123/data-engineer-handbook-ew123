WITH parameters AS (
SELECT 1981::INTEGER AS target_year
)
DELETE FROM actors_history_scd
WHERE current_year = (SELECT target_year FROM parameters);

WITH parameters AS (
    SELECT 1981::INTEGER AS target_year
),
historical_records AS (
SELECT actorid, quality_class, is_active, start_date, end_date
FROM actors_history_scd
WHERE current_year = (SELECT target_year - 1 FROM parameters)
    AND end_date < (SELECT target_year - 1 FROM parameters)
),
previous_open_records AS (
SELECT actorid, quality_class, is_active, start_date, end_date
FROM actors_history_scd
WHERE current_year = (SELECT target_year - 1 FROM parameters)
    AND end_date = (SELECT target_year - 1 FROM parameters)
),
current_actor_data AS (
SELECT actorid, quality_class, is_active, current_year
FROM actors
WHERE current_year = (SELECT target_year FROM parameters)
),
unchanged_records AS (
SELECT
    p.actorid,
    p.quality_class,
    p.is_active,
    p.start_date,
    c.current_year AS end_date
FROM previous_open_records p
INNER JOIN current_actor_data c
    ON p.actorid = c.actorid
WHERE p.quality_class IS NOT DISTINCT FROM c.quality_class
    AND p.is_active IS NOT DISTINCT FROM c.is_active
),
changed_records AS (
SELECT
    change_rows.actorid,
    change_rows.quality_class,
    change_rows.is_active,
    change_rows.start_date,
    change_rows.end_date
FROM previous_open_records p
INNER JOIN current_actor_data c
    ON p.actorid = c.actorid
CROSS JOIN LATERAL (
    VALUES
        (p.actorid, p.quality_class, p.is_active, p.start_date, p.end_date),
        (c.actorid, c.quality_class, c.is_active, c.current_year, c.current_year)
) AS change_rows (
    actorid, quality_class, is_active, start_date, end_date
)
WHERE p.quality_class IS DISTINCT FROM c.quality_class
    OR p.is_active IS DISTINCT FROM c.is_active
),
new_actors AS (
SELECT
    c.actorid,
    c.quality_class,
    c.is_active,
    c.current_year AS start_date,
    c.current_year AS end_date
FROM current_actor_data c
LEFT JOIN previous_open_records p
    ON c.actorid = p.actorid
WHERE p.actorid IS NULL
),
combined_records AS (
SELECT * FROM historical_records
UNION ALL
SELECT * FROM unchanged_records
UNION ALL
SELECT * FROM changed_records
UNION ALL
SELECT * FROM new_actors
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
FROM combined_records;