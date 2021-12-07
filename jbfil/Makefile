
ifdef inpfile
sim_args += +inpfile="$(inpfile)"
endif

ifeq "$(show_read)" "1"
sim_args += +show_read
endif

ifdef loop_limit
sim_args += +loop_limit="$(loop_limit)"
endif

ifeq "$(save)" "1"
save_results = | tail -n +2 > {}.result
endif

LIB = work/_lib.qdb

run: $(LIB)
	vsim -c tb -do "run -all; quit" $(sim_args) | grep -v -x -f filter_lines | sed 's/^# //'

tests: $(LIB)
	find tests/ -iname "*.trace" -exec sh -c "make inpfile=\"{}\" $(save_results)" \;

demo: $(LIB)
	find tests_demo/ -iname "*.trace" -exec sh -c "make inpfile=\"{}\" $(save_results)" \;

$(LIB) : $(wildcard *.sv)
	vlog $^

.PHONY: run tests demo


