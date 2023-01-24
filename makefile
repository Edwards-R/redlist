EXTENSION = redlist
EXTVERSION = 0.0.1

$(EXTENSION)--$(EXTVERSION).sql: \
supporting_functions/*.sql \
reset.sql \
transfer_data.sql \
prepare_data.sql \
cell_counts.sql
	cat $^ > $@