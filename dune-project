(lang dune 3.16)

(name deb_builder)

(generate_opam_files true)

(source
 (github minaprotocol/deb-builder))

(authors "Author Name")

(maintainers "o1 labs <build@o1labs.org>")

(license Apache-2.0)

(package
 (name deb_builder)
 (synopsis "A small utility to build debian packages")
 (version 0.1)
 (depends
  ocaml
  dune
  core
 ))

