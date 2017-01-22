all: names bitfield
names: build/names.c
	cd build && gcc -Os names.c -o ../names
bitfield: build/bitfield.c
	cd build && gcc -Os bitfield.c -o ../bitfield
names-debug: build/names.c
	cd build && gcc names.c --debug=3 -o ../names-debug
