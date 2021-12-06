
ifdef inpfile
sim_args += +inpfile="$(inpfile)"
endif

ifeq "$(show_read)" "1"
sim_args += +show_read
endif

run: work/_lib.qdb
	vsim -c tb -do "run -all; quit" $(sim_args) | grep -v -x -f filter_lines | sed 's/^# //'

work/_lib.qdb : $(wildcard *.sv)
	vlog $^

.PHONY: run


