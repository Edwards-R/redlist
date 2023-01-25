SET SCHEMA 'redlist';

CREATE TABLE redlist.buffer_union AS (

	WITH a AS (
		SELECT * FROM buffer_union('sura_10',40)
	),

	x AS (
		SELECT * FROM buffer_union('sura_10',40, 1992, 2001)
	),

	y AS (
		SELECT * FROM buffer_union('sura_10',40, 2002, 2011)
	),

	z AS (
		SELECT * FROM buffer_union('sura_10',40, 2012, 2021)
	),

	m AS (
		SELECT * FROM buffer_union('sura_10',40, 2012, 2015)
	),

	n AS (
		SELECT * FROM buffer_union('sura_10',40, 2016, 2021)
	)

	SELECT a.tik tik, a.poly map_all, a.sq_km sq_km_all,
	x.poly map_1, x.sq_km sq_km_1,
	y.poly map_2, y.sq_km sq_km_2,
	z.poly map_3, z.sq_km sq_km_3,
	m.poly map_s1, m.sq_km sq_km_s1,
	n.poly map_s2, n.sq_km sq_km_s2

	FROM a
	JOIN x ON a.tik = x.tik
	JOIN y ON a.tik = y.tik
	JOIN z ON a.tik = z.tik
	JOIN m ON a.tik = m.tik
	JOIN n ON a.tik = n.tik
);

CREATE VIEW redlist.buffer_union_summary AS (
	select buf.tik,
	binomial,
	sq_km_all,
	sq_km_1,
	((sq_km_1/sq_km_all::FLOAT)*100)::INT AS "1%A",
	sq_km_2,
	((sq_km_2/sq_km_all::FLOAT)*100)::INT AS "2%A",
	sq_km_3,
	((sq_km_3/sq_km_all::FLOAT)*100)::INT AS "3%A"
	from redlist.buffer_union buf
	JOIN taxonomy.binomial b on buf.tik = b.tik
);