#!/bin/sh
# Test:
#   Run an single-repo install in a directory that is not a Git repository

mkdir /tmp/not-a-git-repo && cd /tmp/not-a-git-repo || exit 1

if sh /var/lib/githooks/install.sh --single; then
    echo "! Expected to fail"
    exit 1
fi
