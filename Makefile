all:
	ln --symbolic --force ucsd-thesis.typ/ucsd_thesis.typ template.typ
	typst compile  -j$(shell nproc)  main_with_template.typ thesis.pdf

clean:
	rm thesis.pdf
