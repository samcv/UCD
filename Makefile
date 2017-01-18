all:
	cd build && gcc -Os bitfield.c -o ../bitfield && gcc -Os names.c -o ../names
names:
	cd build && gcc -Os names.c -o ../names
bitfield:
	cd build && gcc -Os bitfield.c -o ../bitfield
