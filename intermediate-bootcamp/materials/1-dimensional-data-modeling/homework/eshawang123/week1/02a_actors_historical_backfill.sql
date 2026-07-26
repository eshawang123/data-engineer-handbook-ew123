-- Populate actor snapshots for every year from 1970 to 2019.
-- Idempotency:
-- Existing rows for 1970–2019 are deleted and rebuilt inside one transaction. Repeated runs with unchanged source data produce the same final table contents.

DELETE FROM actors
WHERE current_year BETWEEN 1970 AND 2019;


WITH actor_first_year AS (
    SELECT
        actorid,
        MIN(year) AS first_year
    FROM actor_films
    WHERE year BETWEEN 1970 AND 2019
    GROUP BY actorid
),

actor_snapshot_years AS (
    SELECT
        afy.actorid,
        snapshot_year AS current_year
    FROM actor_first_year afy
    CROSS JOIN LATERAL GENERATE_SERIES(
        afy.first_year,
        2019
    ) AS snapshot_year
),

snapshot_data AS (
    SELECT
        asy.actorid,
        asy.current_year,
        actor_name.actor,-- most recently available actor name through this year.
        cumulative_films.films,-- all films released through the snapshot year.
        latest_active_year.average_rating,--average rating from the actor's most recent active year.
        
        EXISTS (
            SELECT 1
            FROM actor_films active_check
            WHERE active_check.actorid = asy.actorid
              AND active_check.year = asy.current_year
        ) AS is_active --TRUE only if the actor released a film in this year.

    FROM actor_snapshot_years asy

    CROSS JOIN LATERAL (
    SELECT af.actor
    FROM actor_films af
    WHERE af.actorid = asy.actorid
        AND af.year <= asy.current_year
    ORDER BY af.year DESC, af.filmid
    LIMIT 1
    ) actor_name

    CROSS JOIN LATERAL (
        SELECT
            ARRAY_AGG(
                ROW(af.film,
                    af.votes,
                    af.rating,
                    af.filmid)::film_struct
                ORDER BY af.year, af.filmid
            ) AS films
        FROM actor_films af
        WHERE af.actorid = asy.actorid
          AND af.year <= asy.current_year
    ) cumulative_films

    CROSS JOIN LATERAL (
        SELECT
            AVG(af.rating) AS average_rating
        FROM actor_films af
        WHERE af.actorid = asy.actorid
          AND af.year = (
              SELECT MAX(latest_year.year)
              FROM actor_films latest_year
              WHERE latest_year.actorid = asy.actorid
                AND latest_year.year <= asy.current_year
          )
    ) latest_active_year
)

INSERT INTO actors (
actor,
actorid,
films,
quality_class,
is_active,
current_year
)
SELECT
actor,
actorid,
films,

CASE
    WHEN average_rating > 8
        THEN 'star'::quality_class
    WHEN average_rating > 7
        THEN 'good'::quality_class
    WHEN average_rating > 6
        THEN 'average'::quality_class
    ELSE 'bad'::quality_class
END AS quality_class,

is_active,
current_year

FROM snapshot_data

ORDER BY
    current_year,
    actorid;