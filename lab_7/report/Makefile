all: compile

compile:
	mkdir -p build
	latexmk -shell-escape -pdf -outdir=build main.tex
	cp build/main.pdf PV_lab_7.pdf

clean:
	rm -rf build
