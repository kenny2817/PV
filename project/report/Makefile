all: compile

compile:
	mkdir -p build
	latexmk -shell-escape -pdf -outdir=build main.tex
	cp build/main.pdf temp.pdf

clean:
	rm -rf build
