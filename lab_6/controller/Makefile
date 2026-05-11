# ============================================================================
# QuestaSim UVM Makefile
# ============================================================================

TEST      ?= ctrl_rnd_test
VERBOSITY ?= UVM_MEDIUM
SEED      ?= random

.PHONY: all comp sim gui clean

all: comp sim

# ----------------------------------------------------------------------------
# Step 1: Compilation
# ----------------------------------------------------------------------------
comp:
	vlib work
	vmap work work
	vlog -work work -sv -timescale "1ns/1ps" +incdir+. \
		simple_mem_ctrl.sv \
		tb_uvm_simple_mem_ctrl.sv

# ----------------------------------------------------------------------------
# Step 2: Simulation (Console / Batch Mode)
# ----------------------------------------------------------------------------
sim:
	vsim -voptargs="+acc" -c -do "run -all; exit" \
		-sv_seed $(SEED) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERBOSITY) \
		work.tb_top

# ----------------------------------------------------------------------------
# Step 3: Simulation (GUI Mode for Waveforms)
# ----------------------------------------------------------------------------
gui:
	vsim -do "add wave -r /*; run -all" \
		-sv_seed $(SEED) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERBOSITY) \
		work.tb_ctrl

# ----------------------------------------------------------------------------
# Cleanup
# ----------------------------------------------------------------------------
clean:
	# Removes all compiled files and logs to give you a fresh start
	rm -rf work transcript vsim.wlf modelsim.ini wlft*