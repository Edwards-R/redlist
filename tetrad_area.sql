CREATE VIEW redlist.tetrad_area AS
WITH raw AS (
	SELECT tik, easting,  northing, accuracy, datum, lower_year
	FROM redlist.sur_2km
	GROUP BY tik, easting, northing, accuracy, datum, lower_year
),
raw_unique AS (
	SELECT tik, count(*) cnt
	FROM raw
	GROUP BY tik, easting, northing, accuracy, datum
),
raw_count AS (
	SELECT tik, count(*) cnt
	FROM raw_unique
	GROUP BY tik
),
slice_1_unique AS (
	SELECT tik
	FROM raw
	WHERE lower_year < 2002
	GROUP BY tik, easting, northing, accuracy, datum
),
slice_1_count AS (
	SELECT tik, count(*) cnt
	FROM slice_1_unique
	GROUP BY tik
),
slice_2_unique AS (
	SELECT tik
	FROM raw
	WHERE lower_year >=  2002
	AND lower_year < 2012
	GROUP BY tik, easting, northing, accuracy, datum
),
slice_2_count AS (
	SELECT tik, count(*) cnt
	FROM slice_2_unique
	GROUP BY tik
),
slice_3_unique AS (
	SELECT tik
	FROM raw
	WHERE lower_year >=  2012
	AND lower_year < 2022
	GROUP BY tik, easting, northing, accuracy, datum
),
slice_3_count AS (
	SELECT tik, count(*) cnt
	FROM slice_3_unique
	GROUP BY tik
)

SELECT n.tik, COALESCE(r.cnt,0)*4 all, COALESCE(s1.cnt,0)*4 slice_1, COALESCE(s2.cnt, 0)*4 slice_2, COALESCE(s3.cnt, 0)*4 slice_3
FROM redlist.nomenclature n
LEFT OUTER JOIN raw_count r on n.tik = r.tik
LEFT OUTER JOIN slice_1_count s1 on n.tik = s1.tik
LEFT OUTER JOIN slice_2_count s2 on n.tik = s2.tik
LEFT OUTER JOIN slice_3_count s3 on n.tik = s3.tik
ORDER BY n.tik;

