SET SCHEMA 'nomenclature';

WITH uniques AS (SELECT DISTINCT(r_tik) FROM binomial)


SELECT r_tik tik, sf.name superfamily, f.name family, r_binomial binomial
FROM binomial b
JOIN species s on b.r_tik = s.id
JOIN genus g on s.parent = g.id
JOIN family f on g.parent = f.id
JOIN superfamily sf on f.parent = sf.id
WHERE r_tik in (SELECT r_tik FROM uniques)
ORDER BY superfamily, family, binomial