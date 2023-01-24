
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
            CASE WHEN r.wales IS NULL THEN 0 ELSE r.wales END wales
            FROM raw_date r
        )',
        view_name, source_name
    );
END
$$;