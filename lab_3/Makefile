all: execute0 execute1 execute2

env:
	source start
	cat link

execute0:
	vsim -c -do "do run.do 0"
	vsim -c -do "do run.do 1"
	vsim -c -do "do run.do 2"
	vsim -c -do "do run.do 3"

execute1:
	vsim -c -do "do run.do 0 1"
	vsim -c -do "do run.do 1 1"
	vsim -c -do "do run.do 2 1"
	vsim -c -do "do run.do 3 1"

execute2:
	vsim -c -do "do run.do 0 2"
	vsim -c -do "do run.do 1 2"
	vsim -c -do "do run.do 2 2"
	vsim -c -do "do run.do 3 2"