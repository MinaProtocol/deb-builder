#!/bin/bash

set -x

function is_commit_tagged() {
    local commit_hash
    commit_hash=$(git rev-parse HEAD)
    if git tag --points-at "$commit_hash" | grep -q .; then
        echo 0
    else
        echo 1
    fi
}

function export_git_env_vars() {
    git tag -l | xargs git tag -d  # Clean up any local tags to avoid conflicts
    git fetch --tags
    if [ $? -ne 0 ]; then
        echo "Failed to fetch Git tags. Ensure you are in a valid Git repository."
        exit 1
    fi
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
    export VERSION="${GIT_TAG}-${GIT_COMMIT}"
    echo "Exported GIT_COMMIT: $GIT_COMMIT"
    echo "Exported GIT_TAG: $GIT_TAG"
    echo "Exported VERSION: $VERSION"
}