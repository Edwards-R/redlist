/*
 * This function:
 *      selects data from the defined table
 *      filters it to the prescribed date range (year 0-3000 default)
 *      translates to a unified datum (27700 as default)
 *      creates a buffer of size 'distance'
 *      merges all the resulting buffers into one polygon
 *
 *  The function is EXTREMELY resources intensive to run, so avoid calling it dynamically
 *  Any pre-optimisation that can be done, should be done.
 *  The function is designed to be used as part of a package that ensures that the data it requires
 *  is available, formatted, and optimised.
 *
 *  There's probably a way to write this as a proper aggregate function, but my brain won't follow it right now
 *  On top of that, this is being written for now rather than later, so *shrug*
 */

CREATE OR REPLACE FUNCTION redlist.buffer_union(
    source_name TEXT, -- The table to use as a data source
    distance    INT, -- Distance of the buffer
    start_year  INT DEFAULT 0, -- Lowest year, inclusive
    end_year    INT DEFAULT 3000, --Highest year, inclusive
    datum       INT DEFAULT 27700 -- The datum to unify all geometry to
)
RETURNS TABLE (
    tik INT,
    poly public.geometry
)
LANGUAGE plpgsql
AS $$
DECLARE

BEGIN
    SET SCHEMA 'redlist';

    RETURN QUERY EXECUTE FORMAT('
        WITH raw AS (
            SELECT tik,
            easting,
            northing,
            accuracy,
            datum
            FROM %I
            WHERE lower_year >= $1
            AND upper_year <= $2
            GROUP BY tik, easting, northing, accuracy, datum
        ),

        b_u AS (
            SELECT
            tik,
            public.ST_UNION(
                public.ST_BUFFER(
                    public.ST_TRANSFORM(
                        redlist.enad_to_poly(
                            easting,
                            northing,
                            accuracy,
                            datum
                        ),
                        27700
                    ),
                    40000
                )
            ) poly
            FROM raw
            GROUP BY tik
        )
        
        SELECT tik, poly
        FROM b_u',
        source_name, start_year, end_year
    )
    USING start_year, end_year;
END;
$$;