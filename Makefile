source_folder = source
build_folder = build
debug_flags = --debug=3
all: names bitfield
names: $(source_folder)/names.c
	mkdir -p $(build_folder) && cd $(source_folder) && gcc -Os names.c -o ../$(build_folder)/names
bitfield: source/bitfield.c
	mkdir -p $(build_folder) && cd $(source_folder) && gcc -Os bitfield.c -o ../$(build_folder)/bitfield
names-debug: source/names.c
	mkdir -p $(build_folder) && cd $(source_folder) && gcc -Os $(debug_flags) names.c -o ../$(build_folder)/names
clean:
	rm -rf $(build_folder)
realclean: clean
	rm -rf $(source_folder)
