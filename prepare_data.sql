-- Set redlist as the working schema
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
);

CREATE TABLE country_outline AS (
    SELECT * FROM public.outline
);

DROP VIEW IF EXISTS redlist.hectad_count;

CREATE VIEW redlist.hectad_count AS

WITH raw AS (
SELECT tik, vc_num
	FROM redlist.sur_10km
	GROUP BY tik, vc_num, easting, northing, accuracy, datum
),

england AS (
	SELECT tik, 'England', count(*)
	FROM raw s 
	JOIN vc_country v ON s.vc_num = v.vc_num
	WHERE v.country= 'England'
	GROUP BY tik
),
wales AS (
	SELECT tik, 'Wales', count(*)
	FROM raw s
	JOIN vc_country v ON s.vc_num = v.vc_num
	WHERE v.country= 'Wales'
	GROUP BY tik
),
scotland AS (
	SELECT tik, 'Scotland', count(*)
	FROM raw s
	JOIN vc_country v ON s.vc_num = v.vc_num
	WHERE v.country= 'Scotland'
	GROUP BY tik
)

SELECT e.tik, COALESCE(e.count,0) england, COALESCE(w.count,0) wales, COALESCE(s.count,0) scotland,
COALESCE(e.count+w.count+s.count,0) combined
FROM england e
LEFT OUTER JOIN wales w on e.tik = w.tik
LEFT OUTER JOIN scotland s on e.tik = s.tik;


