#!/bin/bash

sudo chown -R opam:opam /workdir

set -euox pipefail
# This script builds the application using opam and dune.
# Ensure that the script is run from the root of the repository
if [ ! -f "dune-project" ]; then
  echo "This script must be run from the root of the repository."
  exit 1
fi

eval "$(opam env)"

make dependencies

make build-release

if [ $? -ne 0 ]; then
  echo "Build failed."
  exit 1
fi
echo "Build succeeded."
