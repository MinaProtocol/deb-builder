#!/bin/bash



set -euox pipefail

# This is necessary to ensure that the script can run in a CI environment
sudo chown -R opam:opam /home/opam/.gnupg
sudo chmod 700 /home/opam/.gnupg
sudo chmod 600 /home/opam/.gnupg/*

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
