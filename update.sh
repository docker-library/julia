#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

source '.architectures-lib'

# see https://stackoverflow.com/a/2705678/433558
sed_escape_rhs() {
	echo "$@" | sed -e 's/[\/&]/\\&/g' | sed -e ':a;N;$!ba;s/\n/\\n/g'
}

rcRegex='-(pre[.])?(alpha|beta|rc)[0-9]*'

pattern='[^"]*/julia-([0-9]+\.[0-9]+\.[0-9]+('"$rcRegex"')?)-linux-x86_64\.tar\.gz[^"]*'
allVersions="$(
	curl -fsSL 'https://julialang.org/downloads/' \
		| grep -oE "$pattern" \
		| sed -rn "s!${pattern}!\1!gp" \
		| sort -ruV
)"

for version in "${versions[@]}"; do
	rcVersion="${version%-rc}"
	rcGrepV='-v'
	if [ "$rcVersion" != "$version" ]; then
		rcGrepV=
	fi
	rcGrepV+=' -E'

	fullVersion="$(grep -E "^${rcVersion}([.-]|$)" <<<"$allVersions" | grep $rcGrepV -- "$rcRegex" | head -1)"
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
		sha256="$(grep "julia-${fullVersion}-linux-${tarArch}.tar.gz$" <<<"$sha256s" | cut -d' ' -f1 || :)"
		if [ -z "$sha256" ]; then
			echo >&2 "warning: cannot find sha256 for $fullVersion on arch $tarArch / $dirArch ($dpkgArch); skipping"
			continue
		fi
		bashbrewArch="$(dpkgToBashbrewArch "$version" "$dpkgArch")"
		linuxArchCase+="# $bashbrewArch"$'\n'
		linuxArchCase+=$'\t\t'"$dpkgArch) tarArch='$tarArch'; dirArch='$dirArch'; sha256='$sha256' ;; "$'\\\n'
	done
	linuxArchCase+=$'\t\t''*) echo >&2 "error: current architecture ($dpkgArch) does not have a corresponding Julia binary release"; exit 1 ;; '$'\\\n'
	linuxArchCase+=$'\t''esac'

	winSha256="$(grep "julia-${fullVersion}-win64.exe$" <<<"$sha256s" | cut -d' ' -f1)"

	echo "$version: $fullVersion"

	for v in \
		windows/windowsservercore-{ltsc2016,1809} \
		alpine3.12 \
		{stretch,buster} \
	; do
		dir="$version/$v"
		variant="$(basename "$v")"

		[ -d "$dir" ] || continue

		case "$variant" in
			windowsservercore-*) template='windowsservercore'; tag="${variant#*-}" ;;
			alpine*) template='alpine'; tag="${variant#alpine}" ;;
			*) template='debian'; tag="${variant}-slim" ;;
		esac

		if [ "$version" = '1.0' ] && [ "$template" = 'debian' ] && [ "$variant" = 'stretch' ]; then
			# 1.0-stretch needs to stay non-slim for backwards compatibility
			tag="$variant"
		fi

		variantArchCase="$linuxArchCase"
		if [ "$template" = 'alpine' ]; then
			sha256="$(grep "julia-${fullVersion}-musl-x86_64.tar.gz$" <<<"$sha256s" | cut -d' ' -f1 || :)"
			[ -n "$sha256" ] || continue
			variantArchCase='apkArch="$(apk --print-arch)"; '$'\\\n'
			variantArchCase+=$'\t''case "$apkArch" in '$'\\\n'
			# TODO Alpine multiarch
			variantArchCase+='# amd64'$'\n'
			tarArch="$(dpkgToJuliaTarArch "$version" 'amd64')"
			dirArch="$(dpkgToJuliaDirArch "$version" 'amd64')"
			variantArchCase+=$'\t\t'"x86_64) tarArch='$tarArch'; dirArch='$dirArch'; sha256='$sha256' ;; "$'\\\n'
			variantArchCase+=$'\t\t''*) echo >&2 "error: current architecture ($apkArch) does not have a corresponding Julia binary release"; exit 1 ;; '$'\\\n'
			variantArchCase+=$'\t''esac'
		fi

		sed -r \
			-e 's!%%JULIA_VERSION%%!'"$fullVersion"'!g' \
			-e 's!%%TAG%%!'"$tag"'!g' \
			-e 's!%%JULIA_WINDOWS_SHA256%%!'"$winSha256"'!g' \
			-e 's!%%ARCH-CASE%%!'"$(sed_escape_rhs "$variantArchCase")"'!g' \
			"Dockerfile-$template.template" > "$dir/Dockerfile"

		case "$dir" in
			1.0/windows/*)
				# https://github.com/JuliaLang/julia/blob/v1.4.0-rc1/NEWS.md#build-system-changes
				sed -ri \
					-e 's!/SILENT!/S!g' \
					-e 's!/DIR=!/D=!g' \
					"$dir/Dockerfile"
				;;
		esac
	done
done
