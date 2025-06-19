# Makefile for OCaml project with app in src/bin

OCAMLBUILD=dune
BUILD_DIR=_build
BIN_DIR=src/bin
TEST_DIR=src/test
APP_NAME=deb_builder

.PHONY: all clean build run

build:
	$(OCAMLBUILD) build $(BIN_DIR)/$(APP_NAME).exe

test:
	cd $(TEST_DIR) && $(OCAMLBUILD) test --always-show-test-output

run: build
	./$(BUILD_DIR)/$(BIN_DIR)/$(APP_NAME).exe

clean:
	$(OCAMLBUILD) -clean