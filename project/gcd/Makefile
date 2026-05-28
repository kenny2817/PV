TEST      ?= gcd_bringup_test
VERBOSITY ?= UVM_MEDIUM
SEED      ?= 0

.PHONY: all comp sim clean

all: comp sim

comp:
	vlib work
	vmap work work
	vlog -work work -sv -timescale "1ns/1ps" +incdir+. \
		gcd.sv \
		tb_uvm_gcd.sv

sim:
	vsim -voptargs="+acc" -c -do "run -all; exit" \
		-sv_seed $(SEED) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERBOSITY) \
		work.gcd_top

clean:
	# Removes all compiled files and logs to give you a fresh start
	rm -rf work transcript vsim.wlf modelsim.ini wlft* waves.vcd