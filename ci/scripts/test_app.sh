#!/bin/bash

set -euox pipefail

sudo chown -R opam:opam /workdir

# This script builds the application using opam and dune.
# Ensure that the script is run from the root of the repository
if [ ! -f "dune-project" ]; then
  echo "This script must be run from the root of the repository."
  exit 1
fi

sudo apt-get update
sudo apt-get install -y ca-certificates git fakeroot debsigs
sudo rm -rf /var/lib/apt/lists/*

eval "$(opam env)"

make test-dependencies

make test

if [ $? -ne 0 ]; then
  echo "Test failed."
  exit 1
fi
echo "Test succeeded."
