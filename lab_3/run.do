# 1. Version
set VERSION $1
set FULL_NAME "regfile_v$VERSION"

# 2. Compile
vlog +acc +define+DUT_NAME=$FULL_NAME tb_regfile.sv

# 3. Verbosity
set V=0
if {$argc == 2} { V=$2 }

# 4. Run
vsim -sv_seed 0 work.tb_regfile +VERBOSITY=$2
add wave *
run -all