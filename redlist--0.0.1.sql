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
    (floor(easting/2000)*2000)::INT easting,
    (floor(northing/2000)*2000)::INT northing,
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
);

CREATE TABLE country_outline AS (
    SELECT * FROM public.outline
);
-- This exists to a) export the nomenclature and b) be used in LEFT OUTER JOIN rather than nomenclature.binomial, as that contains non-red list taxa

CREATE VIEW redlist.nomenclature AS
WITH tiks AS
(
	SELECT distinct(tik)
	FROM redlist.simple_unique_record
)

SELECT t.tik, binomial
FROM tiks t
JOIN nomenclature.binomial b on t.tik = b.tik;
SET SCHEMA 'redlist';

-- Make the 10km  regional counts
CALL regional_cells('regional_cells_10km', 'sur_10km');

-- Make the 2km regional counts
CALL regional_cells('regional_cells_2km', 'sur_2km');

DROP SEQUENCE IF EXISTS bump;

CREATE TEMPORARY SEQUENCE bump START 1;

CREATE MATERIALIZED VIEW redlist.buffer_union_map AS (
	WITH clipping_mask AS(
		SELECT public.ST_UNION(geom) mask FROM public.outline WHERE id < 164
	),
	
	all_values AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'all' run
		FROM buffer_union('sura_10km', 40), clipping_mask
	),
	
	slice_one AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 1' run
		FROM buffer_union('sura_10km', 40, 1992, 2001), clipping_mask
	),
	
	slice_two AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 2' run
		FROM buffer_union('sura_10km', 40, 2002, 2011), clipping_mask
	),
	
	slice_three AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 3' run
		FROM buffer_union('sura_10km', 40, 2012, 2021), clipping_mask
	),
	
	slice_two_a AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 2a' run
		FROM buffer_union('sura_10km', 40, 2002, 2006), clipping_mask
	),
	
	slice_two_b AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 2b' run
		FROM buffer_union('sura_10km', 40, 2007, 2011), clipping_mask
	),
	
	slice_three_a AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 3a' run
		FROM buffer_union('sura_10km', 40, 2012, 2016), clipping_mask
	),
	
	slice_three_b AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 3b' run
		FROM buffer_union('sura_10km', 40, 2017, 2021), clipping_mask
	)
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM all_values, clipping_mask
	
	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_one, clipping_mask
	
	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_two, clipping_mask
	
	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_three, clipping_mask
	
	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_two_a, clipping_mask
	
	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_two_b, clipping_mask

	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_three_a, clipping_mask
	
	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_three_b, clipping_mask
);

CREATE VIEW redlist.buffer_union_summary AS (
    WITH slice_all AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'all'
    ),

    slice_one AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 1'
    ),

    slice_two AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 2'
    ),

    slice_three AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 3'
    ),

    slice_two_a AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 2a'
    ),

    slice_two_b AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 2b'
    ),

    slice_three_a AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 3a'
    ),

    slice_three_b AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 3b'
    )

    SELECT n.tik, n.binomial,
    COALESCE(slice_all.sq_km, 0) slice_all,

    COALESCE(slice_one.sq_km, 0) slice_1,
    COALESCE(((slice_one.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_1%all",

    COALESCE(slice_two.sq_km, 0) slice_2,
    COALESCE(((slice_two.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_2%all",

    COALESCE(slice_three.sq_km, 0) slice_3,
    COALESCE(((slice_three.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_3%all",

    COALESCE(slice_two_a.sq_km, 0) slice_2a,
    COALESCE(((slice_two_a.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_2a%all",

    COALESCE(slice_two_b.sq_km, 0) slice_2b,
    COALESCE(((slice_two_b.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_2b%all",

    COALESCE(slice_three_a.sq_km, 0) slice_3a,
    COALESCE(((slice_three_a.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_3a%all",

    COALESCE(slice_three_b.sq_km, 0) slice_3b,
    COALESCE(((slice_three_b.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_3b%all"

    FROM nomenclature n

    LEFT OUTER JOIN slice_all on n.tik = slice_all.tik
    LEFT OUTER JOIN slice_one on n.tik = slice_one.tik
    LEFT OUTER JOIN slice_two on n.tik = slice_two.tik
    LEFT OUTER JOIN slice_three on n.tik = slice_three.tik
    LEFT OUTER JOIN slice_two_a on n.tik = slice_two_a.tik
    LEFT OUTER JOIN slice_two_b on n.tik = slice_two_b.tik
	LEFT OUTER JOIN slice_three_a on n.tik = slice_three_a.tik
    LEFT OUTER JOIN slice_three_b on n.tik = slice_three_b.tik


);SET SCHEMA 'redlist';
CREATE VIEW tetrad_area AS
WITH a AS (
    SELECT tik, COUNT(*)
    FROM sur_2km
    GROUP BY tik
),

x AS (
    SELECT tik, COUNT(*)
    FROM sur_2km
    WHERE lower_year >1991
    AND lower_year <=2001
    GROUP BY tik
),

y AS (
    SELECT tik, COUNT(*)
    FROM sur_2km
    WHERE lower_year >2001
    AND lower_year <=2011
    GROUP BY tik
),

z AS (
    SELECT tik, COUNT(*)
    FROM sur_2km
    WHERE lower_year >2011
    AND lower_year <=2021
    GROUP BY tik
)

-- Multiply by 4 to get sq km (2km x 2km = 4 km sq)
SELECT a.tik, b.binomial,
    COALESCE(a.count*4, 0) all,
    COALESCE(x.count*4, 0) slice_1,
    COALESCE(y.count*4, 0) slice_2,
    COALESCE(z.count*4, 0) slice_3
FROM nomenclature b
LEFT OUTER JOIN a on b.tik = a.tik
LEFT OUTER JOIN x on b.tik = x.tik
LEFT OUTER JOIN y on b.tik = y.tik
LEFT OUTER JOIN z on b.tik = z.tik;
DROP SEQUENCE IF EXISTS tetseq;

CREATE TEMPORARY SEQUENCE tetseq START 1;

CREATE MATERIALIZED VIEW tetrad_map AS
WITH sub_all AS(
    SELECT tik, easting, northing, accuracy, datum
    FROM sura_2km
    GROUP BY tik, easting, northing, accuracy, datum
),

poly_all AS (
    SELECT nextval('tetseq') pk, tik, 'all' run, public.ST_UNION(public.ST_MAKEENVELOPE(easting, northing, easting+accuracy, northing+accuracy, datum)) poly
    FROM sub_all
    GROUP BY tik
),

sub_one AS(
    SELECT tik, easting, northing, accuracy, datum
    FROM sura_2km
    WHERE lower_year >1991
    AND lower_year <=2001
    GROUP BY tik, easting, northing, accuracy, datum
),

poly_one AS (
    SELECT nextval('tetseq') pk, tik, 'slice 1' run, public.ST_UNION(public.ST_MAKEENVELOPE(easting, northing, easting+accuracy, northing+accuracy, datum)) poly
    FROM sub_one
    GROUP BY tik
),

sub_two AS(
    SELECT tik, easting, northing, accuracy, datum
    FROM sura_2km
    WHERE lower_year >2001
    AND lower_year <=2011
    GROUP BY tik, easting, northing, accuracy, datum
),

poly_two AS (
    SELECT nextval('tetseq') pk, tik, 'slice 2' run, public.ST_UNION(public.ST_MAKEENVELOPE(easting, northing, easting+accuracy, northing+accuracy, datum)) poly
    FROM sub_two
    GROUP BY tik
),

sub_three AS(
    SELECT tik, easting, northing, accuracy, datum
    FROM sura_2km
    WHERE lower_year >2011
    AND lower_year <=2021
    GROUP BY tik, easting, northing, accuracy, datum
),

poly_three AS (
    SELECT nextval('tetseq') pk, tik, 'slice 3' run, public.ST_UNION(public.ST_MAKEENVELOPE(easting, northing, easting+accuracy, northing+accuracy, datum)) poly
    FROM sub_three
    GROUP BY tik
)

SELECT pk, tik, run, poly FROM poly_all

UNION

SELECT pk, tik, run, poly FROM poly_one

UNION

SELECT pk, tik, run, poly FROM poly_two

UNION

SELECT pk, tik, run, poly FROM poly_three;
SET SCHEMA 'redlist';
CREATE VIEW record_counts AS
WITH a AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    GROUP BY tik
),

x AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    WHERE lower_year >1991
    AND lower_year <=2001
    GROUP BY tik
),

y AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    WHERE lower_year >2001
    AND lower_year <=2011
    GROUP BY tik
),

z AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    WHERE lower_year >2011
    AND lower_year <=2021
    GROUP BY tik
),

h AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    WHERE lower_year >2001
    AND lower_year <=2006
    GROUP BY tik
),

i AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    WHERE lower_year >2006
    AND lower_year <=2011
    GROUP BY tik
),

j AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    WHERE lower_year >2011
    AND lower_year <=2016
    GROUP BY tik
),

k AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    WHERE lower_year >2016
    AND lower_year <=2021
    GROUP BY tik
)

-- Put it all together, coalesce to remove nulls
SELECT a.tik, b.binomial,
    COALESCE(a.count, 0) all,
    COALESCE(x.count, 0) slice_1,
    COALESCE(y.count, 0) slice_2,
    COALESCE(z.count, 0) slice_3,
    COALESCE(h.count, 0) slice_2a,
    COALESCE(i.count, 0) slice_2b,
    COALESCE(j.count, 0) slice_3a,
    COALESCE(k.count, 0) slice_3b
FROM nomenclature b
LEFT OUTER JOIN a on b.tik = a.tik
LEFT OUTER JOIN x on b.tik = x.tik
LEFT OUTER JOIN y on b.tik = y.tik
LEFT OUTER JOIN z on b.tik = z.tik
LEFT OUTER JOIN h on b.tik = h.tik
LEFT OUTER JOIN i on b.tik = i.tik
LEFT OUTER JOIN j on b.tik = j.tik
LEFT OUTER JOIN k on b.tik = k.tik;
