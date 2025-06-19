#!/bin/bash
set -euox pipefail

source "$(dirname "$0")/helpers.sh"
export_git_env_vars

docker build . -t "minaprotocol/mina-debian-builder:${VERSION}" -f Dockerfile

if [ $? -ne 0 ]; then
  echo "Docker image build failed."
  exit 1
fi
echo "Docker image build succeeded."

docker push "minaprotocol/mina-debian-builder:${VERSION}"