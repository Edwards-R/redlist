SET SCHEMA 'redlist';

CREATE TABLE redlist.buffer_union AS (

	WITH a AS (
		SELECT * FROM buffer_union('sura_10km',40)
	),

	x AS (
		SELECT * FROM buffer_union('sura_10km',40, 1992, 2001)
	),

	y AS (
		SELECT * FROM buffer_union('sura_10km',40, 2002, 2011)
	),

	z AS (
		SELECT * FROM buffer_union('sura_10km',40, 2012, 2021)
	),

	m AS (
		SELECT * FROM buffer_union('sura_10km',40, 2012, 2015)
	),

	n AS (
		SELECT * FROM buffer_union('sura_10km',40, 2016, 2021)
	)

	SELECT b.tik tik, a.poly map_all, a.sq_km sq_km_all,
	x.poly map_1, x.sq_km sq_km_1,
	y.poly map_2, y.sq_km sq_km_2,
	z.poly map_3, z.sq_km sq_km_3,
	m.poly map_s1, m.sq_km sq_km_s1,
	n.poly map_s2, n.sq_km sq_km_s2

	FROM nomenclature b
	LEFT OUTER JOIN a ON b.tik = a.tik
	LEFT OUTER JOIN x ON b.tik = x.tik
	LEFT OUTER JOIN y ON b.tik = y.tik
	LEFT OUTER JOIN z ON b.tik = z.tik
	LEFT OUTER JOIN m ON b.tik = m.tik
	LEFT OUTER JOIN n ON b.tik = n.tik
);

CREATE VIEW redlist.buffer_union_summary AS (
	select buf.tik,
	binomial,
	COALESCE(sq_km_all, 0) AS all,
	COALESCE(sq_km_1, 0) slice_1,
	COALESCE(((sq_km_1/sq_km_all::FLOAT)*100)::INT,0) AS "slice_1%all",
	COALESCE(sq_km_2, 0) slice_2,
	COALESCE(((sq_km_2/sq_km_all::FLOAT)*100)::INT, 0) AS "slice_2%all",
	COALESCE(sq_km_3, 0) slice_3,
	COALESCE(((sq_km_3/sq_km_all::FLOAT)*100)::INT, 0) AS "slice_3%all"
	from redlist.buffer_union buf
	JOIN nomenclature b on buf.tik = b.tik
);