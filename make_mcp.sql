WITH slice_one AS (
    SELECT tik,
    public.ST_AREA(
        public.ST_convexhull(
            public.ST_COLLECT(
                public.ST_MAKEENVELOPE(easting, northing, easting+accuracy, northing+accuracy, datum)
            )
        )
    )/10000 mcp
    FROM sura_10km
    WHERE lower_year >=1992
    AND upper_year <=2001
    GROUP BY tik
),
slice_two AS (
    SELECT tik, 
    public.ST_AREA(
        public.ST_convexhull(
            public.ST_COLLECT(
                public.ST_MAKEENVELOPE(easting, northing, easting+accuracy, northing+accuracy, datum)
            )
        )
    )/10000 mcp
    FROM sura_10km
    WHERE lower_year >=2002
    AND upper_year <=2011
    GROUP BY tik
),
slice_three AS (
    SELECT tik,
    public.ST_AREA(
        public.ST_convexhull(
            public.ST_COLLECT(
                public.ST_MAKEENVELOPE(easting, northing, easting+accuracy, northing+accuracy, datum)
            )
        )
    )/10000 mcp
    FROM sura_10km
    WHERE lower_year >=2012
    AND upper_year <=2021
    GROUP BY tik
)

SELECT n.tik,
COALESCE(slice_one.mcp,0) slice_one,
COALESCE(slice_two.mcp,0) slice_two,
COALESCE(slice_three.mcp,0) slice_three
FROM nomenclature n
LEFT OUTER JOIN slice_one on n.tik = slice_one.tik
LEFT OUTER JOIN slice_two on n.tik = slice_two.tik
LEFT OUTER JOIN slice_three on n.tik = slice_three.tik;
