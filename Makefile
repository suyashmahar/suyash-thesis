all:
	typst compile  -j$(shell nproc)  main_with_template.typ thesis.pdf

clean:
	rm thesis.pdf
