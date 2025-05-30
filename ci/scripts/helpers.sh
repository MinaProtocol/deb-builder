#!/bin/bash

function export_git_env_vars() {
    GIT_TAG=$(git describe --tags --abbrev=0)
    GIT_COMMIT=$(git rev-parse --short HEAD)
    if [ -z "$GIT_TAG" ]; then
        echo "No Git tag found. Ensure you have tags in your repository."
        exit 1
    fi
    if [ -z "$GIT_COMMIT" ]; then
        echo "No Git commit found. Ensure you are in a valid Git repository."
        exit 1
    fi
    export GIT_TAG
    export GIT_COMMIT
    export VERSION="${GIT_TAG}_${GIT_COMMIT}"
    echo "Exported GIT_COMMIT: $GIT_COMMIT"
    echo "Exported GIT_TAG: $GIT_TAG"
    echo "Exported VERSION: $VERSION"
}