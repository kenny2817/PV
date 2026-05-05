all: compile

compile:
	mkdir -p build
	latexmk -pdf -outdir=build main.tex
	cp build/main.pdf temp.pdf

clean:
	rm -rf build
