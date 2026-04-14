# 1. Version
set VERSION $1
set FULL_NAME "regfile_v$VERSION"

# 2. Compile
vlog +acc +define+DUT_NAME=$FULL_NAME tb_regfile.sv

# 3. Execute
if {$argc == 2} {
    vsim work.tb_regfile +VERBOSITY=$2
} else {
    vsim work.tb_regfile
}

# 4. Run
add wave *
run -all