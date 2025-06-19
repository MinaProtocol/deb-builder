#!/bin/bash

set -euox pipefail

git config --global --add safe.directory /workdir

gpg --import /var/secrets/debian/key.gpg

source "$(dirname "$0")/helpers.sh"
export_git_env_vars

mkdir -p ./build_dir

cp _build/default/src/bin/deb_builder.exe ./build_dir/mina-debian-builder

BUILD_URL=${BUILD_URL:-${BUILDKITE_BUILD_URL:-"local build from '$(hostname)' host"}}

mina-debian-builder build --defaults ./ci/res/defaults.json \
    --description "utility for building debian" \
    --debian "./build_dir" \
    --output ./debian/ \
    --arch amd64 \
    --codename bullseye \
    --package-name mina-debian-builder \
    --version ${VERSION} \
    --suite "unstable" \
    --githash "$GIT_COMMIT" \
    --buildurl "$BUILD_URL"

if [ $? -ne 0 ]; then
  echo "Debian package build failed."
  exit 1
fi

echo "Debian package build succeeded."

mina-debian-builder sign --deb ./debian/mina-debian-builder_${VERSION}.deb --key "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"


