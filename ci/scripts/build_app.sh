#!/bin/bash

set -euox pipefail
# This script builds the application using opam and dune.
# Ensure that the script is run from the root of the repository
if [ ! -f "dune-project" ]; then
  echo "This script must be run from the root of the repository."
  exit 1
fi

eval "$(opam env)"

opam switch import opam.export

dune build --profile=release src/bin/deb_builder.exe 

if [ $? -ne 0 ]; then
  echo "Build failed."
  exit 1
fi
echo "Build succeeded."
