# version
set VERSION $1
set FULL_NAME "alu_4bit_v$VERSION"

# compilation
vlog +acc +define+DUT_NAME=$FULL_NAME alu_4bit_tb.sv
vsim work.alu_4bit_tb

# execution
add wave *
restart -f
run -all
