# version
set VERSION $1
set FULL_NAME "reg_file_v$VERSION"

# compilation
vlog +acc +define+DUT_NAME=$FULL_NAME tb_regfile.sv
vsim work.tb_regfile

# execution
add wave *
restart -f
run -all
