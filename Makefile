all:
	cd build && gcc -Os bitfield.c -o ../bitfield && gcc -Os names.c -o ../names
