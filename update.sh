#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

source '.architectures-lib'

# see http://stackoverflow.com/a/2705678/433558
sed_escape_rhs() {
	echo "$@" | sed -e 's/[\/&]/\\&/g' | sed -e ':a;N;$!ba;s/\n/\\n/g'
}

travisEnv=
appveyorEnv=
for version in '.'; do
	pattern='.*/julia-([0-9]+\.[0-9]+\.[0-9]+)-linux-x86_64\.tar\.gz.*'
	fullVersion="$(curl -fsSL 'https://julialang.org/downloads/' | sed -rn "s!${pattern}!\1!gp" | sort -ruV | head -1)"
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
		sha256="$(echo "$sha256s" | grep "julia-${fullVersion}-linux-${tarArch}.tar.gz$" | cut -d' ' -f1)"
		if [ -z "$sha256" ]; then
			echo >&2 "error: cannot find sha256 for $fullVersion on arch $tarArch / $dirArch ($dpkgArch)"
			exit 1
		fi
		linuxArchCase+=$'\t\t'"$dpkgArch) tarArch='$tarArch'; dirArch='$dirArch'; sha256='$sha256' ;; "$'\\\n'
	done
	linuxArchCase+=$'\t\t''*) echo >&2 "error: current architecture ($dpkgArch) does not have a corresponding Julia binary release"; exit 1 ;; '$'\\\n'
	linuxArchCase+=$'\t''esac'

	winSha256="$(echo "$sha256s" | grep "julia-${fullVersion}-win64.exe$" | cut -d' ' -f1)"

	echo "$version: $fullVersion"

	for v in \
		{jessie,stretch} \
		windows/windowsservercore-{1709,ltsc2016} \
	; do
		dir="$version/$v"
		variant="$(basename "$v")"

		mkdir -p "$dir"

		case "$variant" in
			windowsservercore-*) template='windowsservercore'; tag="${variant#*-}" ;;
			*) template='debian'; tag="$variant" ;;
		esac

		sed -r \
			-e 's!%%JULIA_VERSION%%!'"$fullVersion"'!g' \
			-e 's!%%TAG%%!'"$tag"'!g' \
			-e 's!%%JULIA_WINDOWS_SHA256%%!'"$winSha256"'!g' \
			-e 's!%%ARCH-CASE%%!'"$(sed_escape_rhs "$linuxArchCase")"'!g' \
			"Dockerfile-$template.template" > "$dir/Dockerfile"

		case "$v" in
			windows/*-1709) ;; # no AppVeyor support for 1709 yet: https://github.com/appveyor/ci/issues/1885
			windows/*)
				appveyorEnv='\n    - version: '"$version"'\n      variant: '"$variant$appveyorEnv"
				;;
			*)
				for arch in i386 ''; do
					travisEnv='\n'"  - VERSION=$version VARIANT=$v ARCH=$arch$travisEnv"
				done
				;;
		esac
	done
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml

appveyor="$(awk -v 'RS=\n\n' '$1 == "environment:" { $0 = "environment:\n  matrix:'"$appveyorEnv"'" } { printf "%s%s", $0, RS }' .appveyor.yml)"
echo "$appveyor" > .appveyor.yml
