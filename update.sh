#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

source '.architectures-lib'

# see http://stackoverflow.com/a/2705678/433558
sed_escape_rhs() {
	echo "$@" | sed -e 's/[\/&]/\\&/g' | sed -e ':a;N;$!ba;s/\n/\\n/g'
}

for version in '.'; do
	pattern='.*/julia-([0-9]+\.[0-9]+\.[0-9]+)-linux-x86_64\.tar\.gz.*'
	fullVersion="$(curl -fsSL 'https://julialang.org/downloads/' | sed -rn "s!${pattern}!\1!gp")"
	if [ -z "$fullVersion" ]; then
		echo >&2 "error: failed to determine latest release for '$version'"
		exit 1
	fi

	sha256s="$(curl -fsSL "https://julialang-s3.julialang.org/bin/checksums/julia-${fullVersion}.sha256")"

	linuxArchCase='dpkgArch="$(dpkg --print-architecture)"; '$'\\\n'
	linuxArchCase+=$'\t''case "${dpkgArch##*-}" in '$'\\\n'
	for dpkgArch in $(dpkgArches "$version"); do
		tarArch="$(dpkgToJuliaTarArch "$version" "$dpkgArch")"
		dirArch="$(dpkgToJuliaDirArch "$version" "$dpkgArch")"
		sha256="$(echo "$sha256s" | grep "*julia-${fullVersion}-linux-${tarArch}.tar.gz$" | cut -d' ' -f1)"
		if [ -z "$sha256" ]; then
			echo >&2 "error: cannot find sha256 for $fullVersion on arch $tarArch / $dirArch ($dpkgArch)"
			exit 1
		fi
		linuxArchCase+=$'\t\t'"$dpkgArch) tarArch='$tarArch'; dirArch='$dirArch'; sha256='$sha256' ;; "$'\\\n'
	done
	linuxArchCase+=$'\t\t''*) echo >&2 "error: current architecture ($dpkgArch) does not have a corresponding Julia binary release"; exit 1 ;; '$'\\\n'
	linuxArchCase+=$'\t''esac'

	echo "$version: $fullVersion"

	sed -r \
		-e 's!%%JULIA_VERSION%%!'"$fullVersion"'!g' \
		-e 's!%%ARCH-CASE%%!'"$(sed_escape_rhs "$linuxArchCase")"'!g' \
		Dockerfile.template > "$version/Dockerfile"
done
