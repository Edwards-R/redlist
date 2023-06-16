EXTENSION = redlist
EXTVERSION = 0.0.1

$(EXTENSION)--$(EXTVERSION).sql: \
reset.sql \
supporting_functions/*.sql \
transfer_data.sql \
prepare_data.sql \
nomenclature.sql \
cell_counts.sql \
make_buffer_union.sql \
tetrad_area.sql \
tetrad_map.sql \
record_counts.sql \
make_mcp.sql
	cat $^ > $@