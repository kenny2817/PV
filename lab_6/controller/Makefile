TEST      ?= ctrl_rnd_test
VERBOSITY ?= UVM_MEDIUM
SEED      ?= random

.PHONY: all comp sim clean

all: comp sim

comp:
	vlib work
	vmap work work
	vlog -work work -sv -timescale "1ns/1ps" +incdir+. \
		simple_mem_ctrl.sv \
		tb_uvm_simple_mem_ctrl.sv

sim:
	vsim -voptargs="+acc" -c -do "run -all; exit" \
		-sv_seed $(SEED) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERBOSITY) \
		work.tb_ctrl

clean:
	# Removes all compiled files and logs to give you a fresh start
	rm -rf work transcript vsim.wlf modelsim.ini wlft* waves.vcd