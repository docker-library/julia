#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
url='git://github.com/docker-library/julia'
commit="$(git log -1 --format='format:%H' -- Dockerfile $(awk 'toupper($1) == "COPY" { for (i = 2; i < NF; i++) { print $i } }' Dockerfile))"
fullVersion="$(grep -m1 'ENV JULIA_VERSION' Dockerfile | cut -d' ' -f3)"
version="${fullVersion%[.-]*}"

echo '# maintainer: InfoSiftr <github@infosiftr.com> (@infosiftr)'
echo
echo "$fullVersion: ${url}@${commit}"
echo "$version: ${url}@${commit}"
echo "latest: ${url}@${commit}"
