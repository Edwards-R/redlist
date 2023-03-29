/*
 * This script cleans up the previous run of the Redlist so that a new one may commence.
 * It does this rather burtally by just DROPPING everything
 *
 * If you want to keep anything, back it up before running this!
 */

-- Drop any extant redlist schema
DROP SCHEMA IF EXISTS redlist CASCADE;

-- Create the redlist schema
CREATE SCHEMA redlist;CREATE OR REPLACE FUNCTION redlist.enad_to_poly(
    easting INT,
    northing INT,
    accuracy INT,
    datum INT
) RETURNS public.geometry
LANGUAGE plpgsql
AS $$

DECLARE

BEGIN
    RETURN public.st_makeenvelope(
        easting,
        northing,
        easting + accuracy,
        northing + accuracy,
        datum
    );
END;
$$;/*
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
    poly public.geometry,
    sq_km INT
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
        
        SELECT tik, poly, (public.ST_AREA(poly)/1000000)::INT sq_km
        FROM b_u',
        source_name, start_year, end_year
    )
    USING start_year, end_year;
END;
$$;
/*
 * Finds the number of cells, determined by the input data source's resolution, for all the area, then for England, Scotland, and Wales.
 * Then pivots the results into a single line, ready for consumption by the UI
 *
 * New areas can be added easily by adding them to the CTE and then following the established process
 */

CREATE OR REPLACE PROCEDURE redlist.regional_cells(
    view_name TEXT,
    source_name TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE

BEGIN
    SET SCHEMA 'redlist';

    /*
     * This is ugly as all hell, but after 5 repeats of finding an error and changing it in 1km or 10km or whatever, then having to replicate, it's too much
     * Unfortunately since we're creating a view, we have to wrap the SQL in 'execute format', which makes it hellishly hard to comprehend
     * 
     * 'raw' exists to cut down on the number of times I have to pass in the source_name. By having 'raw, I can pass in the source name once, then refer to it internally
     * The alternative is 5 calls to the variable at the very end of the format, which decreases comprehension of the procedure to a horrible degree
     */

    EXECUTE FORMAT('
        CREATE VIEW %I AS (

            WITH raw AS (
                SELECT * FROM %I
            ),

            scotland AS (
                SELECT tik, count(*) cnt FROM raw
                WHERE vc_num BETWEEN 72 AND 112
                GROUP BY tik
            ),

            england AS (
                SELECT tik, count(*) cnt FROM raw
                WHERE vc_num != 35
                AND (
                    vc_num < 41
                    OR vc_num >52
                )
                AND vc_num < 72
                GROUP BY tik
            ),

            wales as (
                SELECT tik, count(*) cnt FROM raw
                WHERE (
                    vc_num = 35
                    OR vc_num BETWEEN 41 AND 52
                )
                GROUP BY tik
            ),

            all_area AS (
                SELECT tik, count(*) cnt FROM raw
                GROUP BY tik
            ),

            raw_date AS (
                SELECT a.tik tik, a.cnt all, e.cnt england, s.cnt scotland, w.cnt wales
                FROM all_area a
                LEFT OUTER JOIN scotland s on a.tik = s.tik
                LEFT OUTER JOIN england e on a.tik = e.tik
                LEFT OUTER JOIN wales w on a.tik = w.tik
            )

            SELECT r.tik,
            CASE WHEN r.all IS NULL THEN 0 ELSE r.all END all,
            CASE WHEN r.england IS NULL THEN 0 ELSE r.england END england,
            CASE WHEN r.scotland IS NULL THEN 0 ELSE r.scotland END scotland,
            CASE WHEN r.wales IS NULL THEN 0 ELSE r.wales END wales
            FROM raw_date r
        )',
        view_name, source_name
    );
END
$$;/*
* This script is responsible for transferring data into the redlist 'source' table
*
* It is recommended to use the follow fields as a minimum:
*
* pk            INT     Primary Key
* tik           INT     Foreign key to taxon name
* binomial      TEXT    The binomial of the taxon, used for fast reference in on-the-fly analysis and during mapping
* gridref       TEXT    The OS GR of the taxon, used for on-the-fly error checking
* easting       INT     The min easting of the record
* northing      INT     The min northing of the record
* accuracy      INT     The accuracy of the record
* datum         INT     The EPSG code of the the record's spatial placement
* vc_num        INT     The Watsonian vice-county ID of the record, used for on-the-fly error checking
* lower_date    DATE    The lower bounding date of the record
* upper_date    DATE    The upper bounding date of the record
* lower_year    INT     The lower bounding year of the record. Saves an unexpected amount of time and increases comprehension significantly.
* upper_year    INT     The upper bounding year of the record. Saves an unexpected amount of time and increases comprehension significantly.
*
*/


/*
 * Save down simple_unique_record to reduce processing time
 *
 * It's a 4-5 second call every time that can be cached right here and save 30+ seconds over the entire processing loop
 *
 * Also take the opportunity to restrict the extracted data to only that relevant to the redlist and add the date as year
 */

SET SCHEMA 'redist';

CREATE MATERIALIZED VIEW redlist.simple_unique_record AS (
    SELECT pk, tik, binomial,
    gridref, easting, northing, accuracy, datum, vc_num,
    lower_date, upper_date,
    date_part('year', lower_date) lower_year,
    date_part('year', upper_date) upper_year
    FROM public.simple_unique_record
    WHERE datum = 27700
    AND date_part('year', lower_date) > 1991
    AND date_part('year', upper_date) <= 2021
);-- Set redlist as the working schema
SET SCHEMA 'redlist';

/*
 * Create the cell-oriented versions as views
 * This is a time-saving and human-re dable thing to do
 * The calculation is very small (<500ms) so can remain as a view
 */

-- Create the 10km resolution version
CREATE VIEW sur_10km AS (
    SELECT tik,
    (floor((easting/10000)*10000))::INT easting,
    (floor((northing/10000)*10000))::INT northing,
    10000 accuracy,
    datum,
    vc_num,
    lower_date, upper_date,
    lower_year, upper_year
    FROM simple_unique_record
);

-- Create the 2km resolution version
CREATE VIEW sur_2km AS (
    SELECT tik,
    (floor((easting/2000)*2000))::INT easting,
    (floor((northing/2000)*2000))::INT northing,
    2000 accuracy,
    datum,
    vc_num,
    lower_date, upper_date,
    lower_year, upper_year
    FROM simple_unique_record
    WHERE accuracy <= 2000
);


-- Simple Unique Record Annual

-- This is the base view to use for mapping and calculating spatial data from as it creates the most optimised cell count possible

CREATE VIEW sura_10km AS (
    SELECT tik,
    easting,
    northing,
    accuracy,
    datum,
    vc_num,
    lower_year, upper_year
    FROM sur_10km
    GROUP BY tik, easting, northing, accuracy, datum, vc_num, lower_year, upper_year
);

CREATE VIEW sura_2km AS (
    SELECT tik,
    easting,
    northing,
    accuracy,
    datum,
    vc_num,
    lower_year, upper_year
    FROM sur_2km
    GROUP BY tik, easting, northing, accuracy, datum, vc_num, lower_year, upper_year
);SET SCHEMA 'redlist';

-- Make the 10km  regional counts
CALL regional_cells('regional_cells_10km', 'sur_10km');

-- Make the 2km regional counts
CALL regional_cells('regional_cells_2km', 'sur_2km');SET SCHEMA 'redlist';

CREATE TABLE redlist.buffer_union AS (

	WITH a AS (
		SELECT * FROM buffer_union('sura_10km',40)
	),

	x AS (
		SELECT * FROM buffer_union('sura_10km',40, 1992, 2001)
	),

	y AS (
		SELECT * FROM buffer_union('sura_10km',40, 2002, 2011)
	),

	z AS (
		SELECT * FROM buffer_union('sura_10km',40, 2012, 2021)
	),

	m AS (
		SELECT * FROM buffer_union('sura_10km',40, 2012, 2015)
	),

	n AS (
		SELECT * FROM buffer_union('sura_10km',40, 2016, 2021)
	)

	SELECT a.tik tik, a.poly map_all, a.sq_km sq_km_all,
	x.poly map_1, x.sq_km sq_km_1,
	y.poly map_2, y.sq_km sq_km_2,
	z.poly map_3, z.sq_km sq_km_3,
	m.poly map_s1, m.sq_km sq_km_s1,
	n.poly map_s2, n.sq_km sq_km_s2

	FROM a
	JOIN x ON a.tik = x.tik
	JOIN y ON a.tik = y.tik
	JOIN z ON a.tik = z.tik
	JOIN m ON a.tik = m.tik
	JOIN n ON a.tik = n.tik
);

CREATE VIEW redlist.buffer_union_summary AS (
	select buf.tik,
	binomial,
	sq_km_all,
	sq_km_1,
	((sq_km_1/sq_km_all::FLOAT)*100)::INT AS "1%A",
	sq_km_2,
	((sq_km_2/sq_km_all::FLOAT)*100)::INT AS "2%A",
	sq_km_3,
	((sq_km_3/sq_km_all::FLOAT)*100)::INT AS "3%A"
	from redlist.buffer_union buf
	JOIN nomenclature.binomial b on buf.tik = b.tik
);