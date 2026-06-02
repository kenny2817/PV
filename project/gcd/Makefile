TEST      ?= gcd_det_test
VERBOSITY ?= UVM_MEDIUM
SEED      ?= 0
TIMEOUT   ?= 1000000ns

FLAGS = -work work -sv -timescale "1ns/1ps" +incdir+.

.PHONY: all comp sim cov formal clean

all: comp sim cov

comp:
	vlib work
	vmap work work
	vlog $(FLAGS) +cover gcd.sv
	vlog $(FLAGS) tb_uvm_gcd.sv

sim:
	vsim -voptargs="+acc" -coverage -c -do "coverage save -onexit cov_db.ucdb; run -all; exit" -sv_seed $(SEED) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERBOSITY) \
		+UVM_TIMEOUT=$(TIMEOUT) \
		work.gcd_top

cov:
	vcover report -details -output coverage_report.txt cov_db.ucdb
	vcover report -details -html -output cov_html cov_db.ucdb
	vcover report cov_db.ucdb >> coverage_report.txt

formal:
	ebmc gcd.sv -D FORMAL --top gcd --bound 20 --systemverilog --trace --waveform --vcd waves.vcd > formal.log

clean:
	rm -rf work transcript vsim.wlf modelsim.ini wlft* waves.vcd coverage_report.txt cov_html cov_db.ucdb formal.log