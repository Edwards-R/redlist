/*
 * TIK only
 * 2,000 m resolution
 * Datum 27700 only aka GB
 * Where lower_year >= 1986
 * Only single day records, no date ranges
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
AND lower_date = upper_date
AND accuracy <= 1000