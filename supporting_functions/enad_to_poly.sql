CREATE OR REPLACE FUNCTION redlist.enad_to_poly(
    easting INT,
    northing INT,
    accuracy INT,
    datum INT
) RETURNS public.geometry
LANGUAGE plpgsql
AS $$

DECLARE

BEGIN
    RETURN public.st_makeenvelope(
        easting,
        northing,
        easting + accuracy,
        northing + accuracy,
        datum
    );
END;
$$;