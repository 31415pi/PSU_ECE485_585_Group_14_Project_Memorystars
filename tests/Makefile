

all: testgen.exe
	testgen.exe -save
	testgen.exe -stress -save
	testgen.exe -random -save


testgen.exe: testgen.c
	gcc -o testgen.exe testgen.c


.PHONY: all


