SET SCHEMA 'redlist';

-- Make the 10km counts
CALL cells('cells_10', 'sur_10');

-- Make the 2km counts
CALL cells('cells_2', 'sur_2');