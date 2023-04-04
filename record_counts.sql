SET SCHEMA 'redlist';
CREATE VIEW record_counts AS
WITH a AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    GROUP BY tik
),

x AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    WHERE lower_year >1991
    AND lower_year <=2001
    GROUP BY tik
),

y AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    WHERE lower_year >2001
    AND lower_year <=2011
    GROUP BY tik
),

z AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    WHERE lower_year >2011
    AND lower_year <=2021
    GROUP BY tik
),

h AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    WHERE lower_year >2011
    AND lower_year <=2016
    GROUP BY tik
),

i AS (
    SELECT tik, COUNT(*)
    FROM simple_unique_record
    WHERE lower_year >2016
    AND lower_year <=2021
    GROUP BY tik
)

-- Put it all together, coalesce to remove nulls
SELECT a.tik, b.binomial,
    COALESCE(a.count, 0) all,
    COALESCE(x.count, 0) slice_1,
    COALESCE(y.count, 0) slice_2,
    COALESCE(z.count, 0) slice_3,
    COALESCE(h.count, 0) slice_3a,
    COALESCE(i.count, 0) slice_3b
FROM nomenclature b
LEFT OUTER JOIN a on b.tik = a.tik
LEFT OUTER JOIN x on b.tik = x.tik
LEFT OUTER JOIN y on b.tik = y.tik
LEFT OUTER JOIN z on b.tik = z.tik
LEFT OUTER JOIN h on b.tik = h.tik
LEFT OUTER JOIN i on b.tik = i.tik