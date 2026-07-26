-- Create the actors cumulative table and supporting types.

DROP TABLE IF EXISTS actors;
DROP TYPE IF EXISTS film_struct;
DROP TYPE IF EXISTS quality_class;


-- for each film inside the actor's films array.
CREATE TYPE film_struct AS (
    film TEXT,
    votes INTEGER,
    rating REAL,
    filmid TEXT
);


-- for actor's quality classification (use enum)
CREATE TYPE quality_class AS ENUM (
    'star',
    'good',
    'average',
    'bad'
);


-- One row per actor per snapshot year.
CREATE TABLE actors (
    actor TEXT NOT NULL,
    actorid TEXT NOT NULL,
    films film_struct[] NOT NULL,-- all films through the current snapshot year.
    quality_class quality_class NOT NULL,-- per the average rating from the actor's most recent active year.
    is_active BOOLEAN NOT NULL,-- TRUE when the actor released at least one film during current_year.
    current_year INTEGER NOT NULL,-- snapshot year.

    PRIMARY KEY (actorid, current_year)
);