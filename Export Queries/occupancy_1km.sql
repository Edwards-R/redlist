/*
 * TIK only
 * 1,000 m resolution
 * Datum 27700 only aka GB
 * Where lower_year >= 1986
 * Where upper_date - lower_date <= 5
 * Where reoslution <= 1000
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
 * OS gridref
 */

SET SCHEMA 'public';

SELECT
tik,
lower_date, upper_date,
TRUNC(easting,-3)::int easting_10000,
TRUNC(northing, -3)::int northing_10000,
1000 as accuracy,
datum,
osgr_to_gridref(
	TRUNC(easting,-3)::int,
	TRUNC(northing, -3)::int,
	1000,
	datum
) os_gridref

FROM sur_mat
WHERE datum = 27700 -- GB Only
AND EXTRACT(YEAR FROM lower_date)::int >= 1986
AND (upper_date - lower_date) <=5
AND accuracy <= 1000