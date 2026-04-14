# version
set VERSION $1
set FULL_NAME "regfile_v$VERSION"

# Default mode is NONE (Silent Regression)
set FLAGS "+VERBOSITY=NONE" 

# Check the second argument to set the verbosity state
if {$argc == 2} {
    if {$2 == "full"} {
        set FLAGS "+VERBOSITY=FULL"
    } elseif {$2 == "errors"} {
        set FLAGS "+VERBOSITY=ERRORS"
    }
}

vlog +acc +define+DUT_NAME=$FULL_NAME tb_regfile.sv
vsim work.tb_regfile $FLAGS
add wave *
run -all