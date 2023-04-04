-- This exists to a) export the nomenclature and b) be used in LEFT OUTER JOIN rather than nomenclature.binomial, as that contains non-red list taxa

CREATE VIEW redlist.nomenclature AS
WITH tiks AS
(
	SELECT distinct(tik)
	FROM redlist.simple_unique_record
)

SELECT t.tik, binomial
FROM tiks t
JOIN nomenclature.binomial b on t.tik = b.tik;
