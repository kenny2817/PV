
# version
set VERSION $1

# verbose
set VERBOSITY ""
if {$argc == 2 && $2 == "verbose"} {
    set VERBOSITY "+VERBOSE"
}

set FULL_NAME "regfile_v$VERSION"

# compilation
vlog +acc +define+DUT_NAME=$FULL_NAME tb_regfile.sv

# execution
vsim work.tb_regfile $VERBOSITY

add wave *
restart -f
run -all