all: compile

compile:
	mkdir -p build
	latexmk -shell-escape -pdf -outdir=build main.tex
	cp build/main.pdf PV_proj.pdf

clean:
	rm -rf build
