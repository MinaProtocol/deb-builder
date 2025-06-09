#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/helpers.sh"
export_git_env_vars

mina-debian-builder build --defaults ./ci/res/defaults.json --output ./debian/ --arch amd64 --release buster --package-name mina-debian-builder --version $VERSION

if [ $? -ne 0 ]; then
  echo "Debian package build failed."
  exit 1
fi

echo "Debian package build succeeded."

mina-debian-builder sign ./debian/mina-debian-builder_${VERSION}_amd64.deb --key "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"


