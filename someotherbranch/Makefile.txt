

run: work/_lib1_0.qtl
	#vsim -c -work work -do "vsim; run -all; exit;"
	#vsim -c -quiet -do "vsim tb; run -all; exit;"
	vsim -c -quiet -do "vsim +infile=input.txt tb; run -all; exit;"

build: work/_lib1_0.qtl

work/_lib1_0.qtl: testbench.sv
	vlog $^

clean:
	rm -rf ece585-dram
	rm -rf work
	rm -f questa.tops
	rm -f transcript

.PHONY: build run clean

