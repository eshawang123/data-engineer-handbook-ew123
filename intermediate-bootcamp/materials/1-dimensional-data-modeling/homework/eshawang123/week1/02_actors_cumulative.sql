-- Populate or replace one actor snapshot year.
-- ON CONFLICT updates an existing actor-year row.
-- Repeated runs for the same target year produce the same result when source and preceding-year data are unchanged.

WITH parameters AS (
    -- we have historical data from beginning to 2019 repopulated.
    SELECT 2020::INTEGER AS target_year
),

previous_year AS (
    SELECT
        actor,
        actorid,
        films,
        quality_class,
        is_active,
        current_year
    FROM actors
    WHERE current_year = (
        SELECT target_year - 1
        FROM parameters
    )
),

current_year_films AS (
    SELECT
        af.actor,
        af.actorid,

        ARRAY_AGG(
            ROW(af.film,
                af.votes,
                af.rating,
                af.filmid)::film_struct
            ORDER BY af.year, af.filmid
        ) AS films,

        AVG(af.rating) AS average_rating

    FROM actor_films af

    WHERE af.year = (
        SELECT target_year
        FROM parameters
    )

    GROUP BY
        af.actor,
        af.actorid
),

combined AS (
    SELECT
        COALESCE(c.actor, p.actor) AS actor,
        COALESCE(c.actorid, p.actorid) AS actorid,

        CASE
            WHEN p.actorid IS NULL
                THEN c.films
            WHEN c.actorid IS NULL
                THEN p.films
            ELSE p.films || c.films
        END AS films,

        CASE
            WHEN c.actorid IS NOT NULL THEN
                CASE
                    WHEN c.average_rating > 8
                        THEN 'star'::quality_class
                    WHEN c.average_rating > 7
                        THEN 'good'::quality_class
                    WHEN c.average_rating > 6
                        THEN 'average'::quality_class
                    ELSE 'bad'::quality_class
                END
            ELSE p.quality_class
        END AS quality_class,

        c.actorid IS NOT NULL AS is_active,

        (
            SELECT target_year
            FROM parameters
        ) AS current_year

    FROM previous_year p

    FULL OUTER JOIN current_year_films c
        ON p.actorid = c.actorid
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
quality_class,
is_active,
current_year

FROM combined

ON CONFLICT (actorid, current_year)
DO UPDATE SET
    actor = EXCLUDED.actor,
    films = EXCLUDED.films,
    quality_class = EXCLUDED.quality_class,
    is_active = EXCLUDED.is_active;