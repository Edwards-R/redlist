SET SCHEMA 'redlist';

-- Make the 10km  regional counts
CALL regional_cells('regional_cells_10km', 'sur_10km');

-- Make the 2km regional counts
CALL regional_cells('regional_cells_2km', 'sur_2km');