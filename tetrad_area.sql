SET SCHEMA 'redlist';
CREATE VIEW tetrad_area AS
WITH a AS (
    SELECT tik, COUNT(*)
    FROM sur_2km
    GROUP BY tik
),

x AS (
    SELECT tik, COUNT(*)
    FROM sur_2km
    WHERE lower_year >1991
    AND lower_year <=2001
    GROUP BY tik
),

y AS (
    SELECT tik, COUNT(*)
    FROM sur_2km
    WHERE lower_year >2001
    AND lower_year <=2011
    GROUP BY tik
),

z AS (
    SELECT tik, COUNT(*)
    FROM sur_2km
    WHERE lower_year >2011
    AND lower_year <=2021
    GROUP BY tik
)

-- Multiply by 4 to get sq km (2km x 2km = 4 km sq)
SELECT a.tik, b.binomial,
    COALESCE(a.count*4, 0) all,
    COALESCE(x.count*4, 0) slice_1,
    COALESCE(y.count*4, 0) slice_2,
    COALESCE(z.count*4, 0) slice_3
FROM nomenclature b
LEFT OUTER JOIN a on b.tik = a.tik
LEFT OUTER JOIN x on b.tik = x.tik
LEFT OUTER JOIN y on b.tik = y.tik
LEFT OUTER JOIN z on b.tik = z.tik
