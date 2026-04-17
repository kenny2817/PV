UNIT   = decode_unit
VFLAGS = +acc

library:
	vlib work
	vmap work ./work

compile:
	vlog $(VFLAGS) $(UNIT).v
	vlog $(VFLAGS) tb_$(UNIT).sv

run: compile
	vsim -c work.tb_$(UNIT) -do "run -all; quit -f"

clean:
	rm -rf work transcript vsim.wlf modelsim.ini
