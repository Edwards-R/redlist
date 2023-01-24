-- Set redlist as the working schema
SET SCHEMA 'redlist';

/*
 * Create the cell-oriented versions as views
 * This is a time-saving and human-re dable thing to do
 * The calculation is very small (<500ms) so can remain as a view
 */

-- Create the 10km resolution version
CREATE VIEW sur_10 AS (
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
CREATE VIEW sur_2 AS (
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


-- Simple Unique Annual Record

-- This is the base view to use for mapping and calculating spatial data from as it creates the most optimised cell count possible

CREATE VIEW sura_10 AS (
    SELECT tik,
    easting,
    northing,
    accuracy,
    datum,
    vc_num,
    lower_year, upper_year
    FROM sur_10
    GROUP BY tik, easting, northing, accuracy, datum, vc_num, lower_year, upper_year
);

CREATE VIEW sura_2 AS (
    SELECT tik,
    easting,
    northing,
    accuracy,
    datum,
    vc_num,
    lower_year, upper_year
    FROM sur_2
    GROUP BY tik, easting, northing, accuracy, datum, vc_num, lower_year, upper_year
);