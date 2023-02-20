/*
 * TIK only
 * 2,000 m resolution
 * Datum 27700 only aka GB
 * Where lower_year >= 1986
 * Where upper_date - lower_date <= 5
 * WHERE accuracy <= 1000
 *
 *
 * Attribute Order:
 * 
 * tik
 * lower_date (YYYY-mm-DD)
 * upper_date (YYYY-mm-DD)
 * easting
 * northing
 * accuracy
 * datum
 */

SET SCHEMA 'public';

SELECT
tik,
lower_date, upper_date,
(FLOOR(easting/2000)*2000)::int easting_2000,
(FLOOR(northing/2000)*2000)::int northing_2000,
2000 as accuracy,
datum

FROM sur_mat
WHERE datum = 27700 -- GB Only
AND EXTRACT(YEAR FROM lower_date)::int >= 1986
AND (upper_date - lower_date) <=5
AND accuracy <= 1000