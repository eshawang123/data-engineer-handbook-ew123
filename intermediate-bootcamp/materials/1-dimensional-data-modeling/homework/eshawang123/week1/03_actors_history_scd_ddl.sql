DROP TABLE IF EXISTS actors_history_scd;

CREATE TABLE actors_history_scd (
    actorid TEXT NOT NULL,
    quality_class quality_class NOT NULL,
    is_active BOOLEAN NOT NULL,
    start_date INTEGER NOT NULL,
    end_date INTEGER NOT NULL,
    current_year INTEGER NOT NULL,
    PRIMARY KEY (actorid, start_date, current_year),
    CHECK (start_date <= end_date),
    CHECK (end_date <= current_year)
);