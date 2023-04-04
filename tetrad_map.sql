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
