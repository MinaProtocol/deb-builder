#!/bin/bash



set -euox pipefail

sudo chown -R opam . && su - opam 

# This script builds the application using opam and dune.
# Ensure that the script is run from the root of the repository
if [ ! -f "dune-project" ]; then
  echo "This script must be run from the root of the repository."
  exit 1
fi

eval "$(opam env)"

opam install dolog fileutils jingoo

make test

if [ $? -ne 0 ]; then
  echo "Test failed."
  exit 1
fi
echo "Test succeeded."
