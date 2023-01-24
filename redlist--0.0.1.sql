
/*
 * Finds the number of cells, determined by the input data source's resolution, for all the area, then for England, Scotland, and Wales.
 * Then pivots the results into a single line, ready for consumption by the UI
 *
 * New areas can be added easily by adding them to the CTE and then following the established process
 */

CREATE OR REPLACE PROCEDURE redlist.cells(
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
            CASE WHEN r.wales IS NULL THEN 0 ELSE r.wales END wales,
            FROM raw_date r
        )',
        view_name, source_name
    );
END
$$;/*
 * This script cleans up the previous run of the Redlist so that a new one may commence.
 * It does this rather burtally by just DROPPING everything
 *
 * If you want to keep anything, back it up before running this!
 */

-- Drop any extant redlist schema
DROP SCHEMA IF EXISTS redlist CASCADE;

-- Create the redlist schema
CREATE SCHEMA redlist;/*
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

CREATE TABLE redlist.simple_unique_record AS (
    SELECT pk, tik, binomial,
    gridref, easting, northing, accuracy, datum, vc_num,
    lower_date, upper_date,
    date_part('year', lower_date) lower_year,
    date_part('year', upper_date) upper_year
    FROM public.simple_unique_record
    WHERE datum = 27700
    AND date_part('year', lower_date) > 1995
    AND date_part('year', upper_date) <= 2021
);-- Set redlist as the working schema
SET SCHEMA 'redlist';

/*
 * Create the cell-oriented versions as views
 * This is a time-saving and human-re dable thing to do
 * The calculation is very small (<500ms) so can remain as a view
 */

-- Create the 10km resolution version
CREATE VIEW sur_10 AS (
    SELECT tik,
    floor((easting/10000)*10000) easting,
    floor((northing/10000)*10000) northing,
    10000 accuracy,
    datum,
    vc_num,
    lower_date, upper_date,
    lower_year, upper_year
    FROM simple_unique_record
);

-- Create the 2km resolution version
CREATE VIEW sur_2 AS (
    SELECT tik,
    floor((easting/2000)*2000) easting,
    floor((northing/2000)*2000) northing,
    2000 accuracy,
    datum,
    vc_num,
    lower_date, upper_date,
    lower_year, upper_year
    FROM simple_unique_record
    WHERE accuracy <= 2000
);SET SCHEMA 'redlist';

-- Make the 10km counts
CALL cells('cells_10', 'sur_10');

-- Make the 2km counts
CALL cells('cells_2', 'sur_2');