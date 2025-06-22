# Makefile for OCaml project with app in src/bin

OCAMLBUILD=dune
BUILD_DIR=_build
BIN_DIR=src/bin
TEST_DIR=src/test
APP_NAME=deb_builder

.PHONY: all clean build run

build:
	$(OCAMLBUILD) build $(BIN_DIR)/$(APP_NAME).exe

build-release:
	$(OCAMLBUILD) build --profile=release $(BIN_DIR)/$(APP_NAME).exe

dependencies:
	opam install dune core async dolog fileutils jingoo ppx_jane ocamlfind yojson ppx_deriving_yojson

test-dependencies: dependencies
	opam install re2 alcotest-async

test:
	cd $(TEST_DIR) && $(OCAMLBUILD) test

run: build
	./$(BUILD_DIR)/$(BIN_DIR)/$(APP_NAME).exe

clean:
	$(OCAMLBUILD) -clean