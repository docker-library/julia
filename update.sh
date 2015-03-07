#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
pattern='.*\/julia-([0-9]+\.[0-9]+\.[0-9]+)-linux-x86_64\.tar\.gz.*'
version=$(curl -sSL 'http://julialang.org/downloads/' | sed -rn "s/${pattern}/\1/gp")

sed -ri 's/^(ENV JULIA_VERSION) .*/\1 '"$version"'/' "Dockerfile"

