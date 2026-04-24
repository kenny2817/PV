UNIT   = simple_cache
VFLAGS = +acc +cover
# +cover enables code coverage metrics
#     (s=stmt, b=branch, c=cond, e=expr, f=fsm, t=toggle)

library:
	vlib work
	vmap work ./work

compile:
	vlog $(VFLAGS) $(UNIT).sv
	vlog $(VFLAGS) tb_$(UNIT).sv

run: compile
	vsim -c -coverage work.tb_$(UNIT) -do "coverage save -onexit test1.ucb; run -all; quit -f"

report:
	vcover report test1.ucb

report_html:
	vcover report -html -output coverage_report test1.ucb

clean:
	rm -rf work transcript vsim.wlf modelsim.ini coverage_report *.ucb

.PHONY: library compile run report clean
