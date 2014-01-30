.PHONY: all clean install build
all: build

J=4

export OCAMLRUNPARAM=b

include config.mk
config.mk: configure
	./configure

configure: configure.ml
	ocamlfind ocamlopt -package "cmdliner" -linkpkg $< -o $@
	rm -f configure.c* configure.o

setup.bin: setup.ml
	@ocamlopt.opt -o $@ $< || ocamlopt -o $@ $< || ocamlc -o $@ $<
	@rm -f setup.cmx setup.cmi setup.o setup.cmo

setup.data: setup.bin
	@./setup.bin -configure --enable-tests $(ENABLE_XENCTRL)

build: setup.data setup.bin
	@./setup.bin -build -j $(J)

doc: setup.data setup.bin
	@./setup.bin -doc -j $(J)

install: setup.bin
	@./setup.bin -install

test: setup.bin build
	@./setup.bin -test

reinstall: setup.bin
	@ocamlfind remove xen-evtchn || true
	@./setup.bin -reinstall

uninstall:
	@ocamlfind remove xen-evtchn || true

clean:
	@ocamlbuild -clean
	@rm -f setup.data setup.log setup.bin
