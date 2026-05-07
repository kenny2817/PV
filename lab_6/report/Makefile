all: compile

compile:
	mkdir -p build
	latexmk -pdf -outdir=build main.tex
	cp build/main.pdf PV_lab_6.pdf

clean:
	rm -rf build
