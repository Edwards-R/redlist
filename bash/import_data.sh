for FILE in data/*;
do
	echo $FILE
	psql -U rowan -d redlist -h 192.168.1.51   -c "\copy data_in.import FROM '$FILE' DELIMITER ',' CSV HEADER ;"
	psql -U rowan -d redlist -h 192.168.1.51   -c "CALL data_in.do_import();"
done