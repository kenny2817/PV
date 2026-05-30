TEST      ?= gcd_bringup_test
VERBOSITY ?= UVM_MEDIUM
SEED      ?= 0
TIMEOUT   ?= 10000ns

.PHONY: all comp sim clean

all: comp sim cov formal

comp:
	vlib work
	vmap work work
	vlog -work work -sv -timescale "1ns/1ps" +incdir+. +cover \
		gcd.sv \
		tb_uvm_gcd.sv

sim:
	vsim -voptargs="+acc" -coverage -c -do "coverage save -onexit cov_db.ucb; run -all; exit" \
		-sv_seed $(SEED) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERBOSITY) \
		+UVM_TIMEOUT=$(TIMEOUT) \
		work.gcd_top

cov:
	vcover report -details -file coverage_report.txt cov_db.ucdb
	vcover report -details -html -htmldir cov_html cov_db.ucdb

formal:
	ebmc gcd.sv -D FORMAL --top gcd --bound 20 --systemverilog --trace --waveform --vcd waves.vcd > formal.log

clean:
	rm -rf work transcript vsim.wlf modelsim.ini wlft* waves.vcd coverage_report.txt cov_html cov_db.ucdb formal.log