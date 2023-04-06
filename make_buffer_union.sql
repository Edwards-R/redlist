DROP SEQUENCE IF EXISTS bump;

CREATE TEMPORARY SEQUENCE bump START 1;

CREATE MATERIALIZED VIEW redlist.buffer_union_map AS (
	WITH clipping_mask AS(
		SELECT public.ST_UNION(geom) mask FROM public.outline WHERE id < 164
	),
	
	all_values AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'all' run
		FROM buffer_union('sura_10km', 40), clipping_mask
	),
	
	slice_one AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 1' run
		FROM buffer_union('sura_10km', 40, 1992, 2001), clipping_mask
	),
	
	slice_two AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 2' run
		FROM buffer_union('sura_10km', 40, 2002, 2011), clipping_mask
	),
	
	slice_three AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 3' run
		FROM buffer_union('sura_10km', 40, 2012, 2021), clipping_mask
	),
	
	slice_two_a AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 2a' run
		FROM buffer_union('sura_10km', 40, 2002, 2006), clipping_mask
	),
	
	slice_two_b AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 2b' run
		FROM buffer_union('sura_10km', 40, 2007, 2011), clipping_mask
	),
	
	slice_three_a AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 3a' run
		FROM buffer_union('sura_10km', 40, 2012, 2016), clipping_mask
	),
	
	slice_three_b AS (
		SELECT nextval('bump') pk,
		tik,
		public.ST_INTERSECTION(poly, mask) poly,
		'slice 3b' run
		FROM buffer_union('sura_10km', 40, 2017, 2021), clipping_mask
	)
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM all_values, clipping_mask
	
	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_one, clipping_mask
	
	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_two, clipping_mask
	
	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_three, clipping_mask
	
	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_two_a, clipping_mask
	
	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_two_b, clipping_mask

	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_three_a, clipping_mask
	
	UNION
	
	SELECT pk, tik, run, (public.ST_AREA(poly)/1000000)::INT sq_km, poly FROM slice_three_b, clipping_mask
);

CREATE VIEW redlist.buffer_union_summary AS (
    WITH slice_all AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'all'
    ),

    slice_one AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 1'
    ),

    slice_two AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 2'
    ),

    slice_three AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 3'
    ),

    slice_two_a AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 2a'
    ),

    slice_two_b AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 2b'
    ),

    slice_three_a AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 3a'
    ),

    slice_three_b AS (
        SELECT tik, sq_km FROM buffer_union_map WHERE run = 'slice 3b'
    )

    SELECT n.tik, n.binomial,
    COALESCE(slice_all.sq_km, 0) slice_all,

    COALESCE(slice_one.sq_km, 0) slice_1,
    COALESCE(((slice_one.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_1%all",

    COALESCE(slice_two.sq_km, 0) slice_2,
    COALESCE(((slice_two.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_2%all",

    COALESCE(slice_three.sq_km, 0) slice_3,
    COALESCE(((slice_three.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_3%all",

    COALESCE(slice_two_a.sq_km, 0) slice_2a,
    COALESCE(((slice_two_a.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_2a%all",

    COALESCE(slice_two_b.sq_km, 0) slice_2b,
    COALESCE(((slice_two_b.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_2b%all",

    COALESCE(slice_three_a.sq_km, 0) slice_3a,
    COALESCE(((slice_three_a.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_3a%all",

    COALESCE(slice_three_b.sq_km, 0) slice_3b,
    COALESCE(((slice_three_b.sq_km/slice_all.sq_km::FLOAT)*100)::INT,0) AS "slice_3b%all"

    FROM nomenclature n

    LEFT OUTER JOIN slice_all on n.tik = slice_all.tik
    LEFT OUTER JOIN slice_one on n.tik = slice_one.tik
    LEFT OUTER JOIN slice_two on n.tik = slice_two.tik
    LEFT OUTER JOIN slice_three on n.tik = slice_three.tik
    LEFT OUTER JOIN slice_three_a on n.tik = slice_three_a.tik
    LEFT OUTER JOIN slice_three_b on n.tik = slice_three_b.tik


);