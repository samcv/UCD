source_folder = source
build_folder = build
debug_flags = --debug=3 -O0
comp_flags = -std=c99
compilier = clang
comp = $(compilier) $(comp_flags)

all: names-debug bitfield-debug
release: names bitfield
names: names-debug
names-release: $(source_folder)/names.c
	mkdir -p $(build_folder) && cd $(source_folder) && $(comp) names.c -o ../$(build_folder)/names
bitfield: bitfield-debug
bitfield-debug: source/bitfield.c
	mkdir -p $(build_folder) && cd $(source_folder) && $(comp) $(debug_flags) bitfield.c -o ../$(build_folder)/bitfield
bitfield-release: source/bitfield.c
	mkdir -p $(build_folder) && cd $(source_folder) && $(comp) bitfield.c -o ../$(build_folder)/bitfield
names-debug: source/names.c
	mkdir -p $(build_folder) && cd $(source_folder) && $(comp) $(debug_flags) names.c -o ../$(build_folder)/names
alias: source/property-value-c-array.c
	mkdir -p $(build_folder) && cd $(source_folder) && $(comp) $(debug_flags) property-value-c-array.c -o ../$(build_folder)/property-value-c-array
clean:
	rm -rf $(build_folder)
realclean: clean
	rm -rf $(source_folder)
