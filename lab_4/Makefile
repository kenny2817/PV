IFLAGS = -g2012 -Wall
MODULES_DIR = mod
PKG_DIR = pkg
TB_DIR = tb
# PKGS = $(PKG_DIR)/alu_pkg.sv $(PKG_DIR)/cmp_pkg.sv $(PKG_DIR)/opcodes_pkg.sv
PKGS = $(PKG_DIR)/*

define IVERILOG_COMPILE
	@iverilog $(IFLAGS) -s $@_tb -o $@ $^ || (echo "failed - $@"; exit 1)
	@echo "success - $@"
endef

define VERILATOR_COMPILE
    @mkdir -p build/$@
    
    @verilator -Wall -Wno-fatal --binary --trace --timing --assert \
        --Mdir build/$@ \
        --top-module $1 \
        -o $@ \
        $(filter-out $@,$^) || \
        (echo "failed - $@"; exit 1)
        
    @cp build/$@/$@ $@
    
    @echo "success - $@"
    @echo "Executable is at $@"
endef

.PHONY: all clean

fetch: fetch/fetch_unit.v fetch/tb_fetch_unit.sv
	$(call VERILATOR_COMPILE, tb_fetch_unit)
	./$@/$@ +verilator+error+limit+0

decode: decode/decode_unit.v decode/tb_decode_unit.sv
	$(call VERILATOR_COMPILE, tb_decode_unit)
	./$@/$@ +verilator+error+limit+0

clean:
	rm *.vcd
