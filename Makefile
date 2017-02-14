source_folder = source
build_folder = build
debug_flags = --debug=3
comp_flags = -std=c99
compilier = gcc
comp = $(compilier) $(comp_flags)

all: names bitfield
names: $(source_folder)/names.c
	mkdir -p $(build_folder) && cd $(source_folder) && $(comp) names.c -o ../$(build_folder)/names
bitfield-debug: source/bitfield.c
	mkdir -p $(build_folder) && cd $(source_folder) && $(comp) $(debug_flags) bitfield.c -o ../$(build_folder)/bitfield
bitfield: source/bitfield.c
	mkdir -p $(build_folder) && cd $(source_folder) && $(comp) bitfield.c -o ../$(build_folder)/bitfield
names-debug: source/names.c
	mkdir -p $(build_folder) && cd $(source_folder) && $(comp) $(debug_flags) names.c -o ../$(build_folder)/names
clean:
	rm -rf $(build_folder)
realclean: clean
	rm -rf $(source_folder)
