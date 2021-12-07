
ifdef inpfile
sim_args += +inpfile="$(inpfile)"
endif

ifeq "$(show_read)" "1"
sim_args += +show_read
endif

ifdef loop_limit
sim_args += +loop_limit="$(loop_limit)"
endif

ifdef verbose
sim_args += +verbose=$(verbose)
endif

ifeq "$(save)" "1"
save_results = | tail -n +2 > {}.result
endif

LIB = work/built.signal


run: $(LIB)
	vsim -c tb -do "run -all; quit" $(sim_args) | grep -v -x -f filter | sed 's/^# //'

debug: $(LIB)
	vsim -c tb -do "run -all; quit" $(sim_args) | grep -v -x -f filter_license | sed 's/^# //'

build: $(LIB)


tests: $(LIB)
	find tests/ -iname "*.txt" -exec sh -c "make inpfile=\"{}\" $(save_results)" \;

demo: $(LIB)
	find tests_demo/ -iname "*.trace" -exec sh -c "make inpfile=\"{}\" $(save_results)" \;

$(LIB) : $(wildcard *.sv)
	vlog $^
	touch $@ # Only touch this file after successful build...

help:
	@echo "targets: run build debug tests demo help"
	@echo " run   - build and run with clean output."
	@echo " debug - build and run with raw vsim output. (license hidden)"
	@echo " build - build system verilog files."
	@echo " tests - run tests"
	@echo " demo  - run tests for demo"
	@echo ""
	@echo " Also supports some arguments to the makefile."
	@echo ""
	@echo "  inpfile=FILE  will use that file as input to the run/debug modes."
	@echo "  show_read=1   will enable display of each output line read in."
	@echo "  loop_limit=N  will limit the simulation loop to N iterations."
	@echo "  save=1        will save the output of test cases to '<test_file>.result'"
	@echo "  verbose=N     will output additional data."
	@echo "                0 - None   1 - Page hits, miss, empty   2 - bank commands"
	@echo "                3 - queued commands   4 - explicit row, bank, col, grp"
	@echo "                9+ - check and address map."



.PHONY: run build debug tests demo help


