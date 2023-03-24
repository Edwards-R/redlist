/*
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
);