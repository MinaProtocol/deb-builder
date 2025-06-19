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


if ! is_commit_tagged; then
  echo "The current commit is not tagged. Skipping Docker push."
  exit 0
fi

docker push "minaprotocol/mina-debian-builder:${VERSION}"