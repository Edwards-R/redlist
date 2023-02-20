/*
 * TIK only
 * 10,000 m resolution
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
 * OS gridref
 */

SET SCHEMA 'public';

SELECT
tik,
lower_date, upper_date,
TRUNC(easting,-4)::int easting_10000,
TRUNC(northing, -4)::int northing_10000,
10000 as accuracy,
datum,
osgr_to_gridref(
	TRUNC(easting,-4)::int,
	TRUNC(northing, -4)::int,
	10000,
	datum
) os_gridref

FROM sur_mat
WHERE datum = 27700 -- GB Only
AND EXTRACT(YEAR FROM lower_date)::int >= 1986
AND lower_date = upper_date