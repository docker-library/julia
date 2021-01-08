#!/usr/bin/env bash
set -Eeuo pipefail

declare -A aliases=(
	[1.5]='1 latest'
)
defaultDebianVariant='buster'
defaultAlpineVariant='alpine3.12'

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )

# sort version numbers with highest first
IFS=$'\n'; versions=( $(echo "${versions[*]}" | sort -rV) ); unset IFS

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		fileCommit \
			Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						print $i
					}
				}
			')
	)
}

getArches() {
	local repo="$1"; shift
	local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'

	eval "declare -g -A parentRepoToArches=( $(
		find -name 'Dockerfile' -exec awk '
				toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|.*\/.*)(:|$)/ {
					print "'"$officialImagesUrl"'" $2
				}
			' '{}' + \
			| sort -u \
			| xargs bashbrew cat --format '[{{ .RepoName }}:{{ .TagName }}]="{{ join " " .TagEntry.Architectures }}"'
	) )"
}
getArches 'julia'

source '.architectures-lib'

parentArches() {
	local version="$1"; shift # "1.8", etc
	local dir="$1"; shift # "1.8/windows/windowsservercore-ltsc2016"

	local parent="$(awk 'toupper($1) == "FROM" { print $2 }' "$dir/Dockerfile")"
	local parentArches="${parentRepoToArches[$parent]:-}"

	local arches=()
	for arch in $parentArches; do
		if hasBashbrewArch "$version" "$arch" && grep -qE "^# $arch\$" "$dir/Dockerfile"; then
			arches+=( "$arch" )
		fi
	done
	echo "${arches[*]}"
}

cat <<-EOH
# this file is generated via https://github.com/docker-library/julia/blob/$(fileCommit "$self")/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon),
             Joseph Ferguson <yosifkit@gmail.com> (@yosifkit)
GitRepo: https://github.com/docker-library/julia.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version in "${versions[@]}"; do
	for v in \
		{buster,stretch} \
		alpine3.12 \
		windows/windowsservercore-{1809,ltsc2016} \
	; do
		dir="$version/$v"
		dir="${dir#./}"
		variant="$(basename "$v")"

		[ -f "$dir/Dockerfile" ] || continue

		commit="$(dirCommit "$dir")"

		fullVersion="$(git show "$commit":"$dir/Dockerfile" | awk '$1 == "ENV" && $2 == "JULIA_VERSION" { print $3; exit }')"

		versionAliases=()
		while [ "$fullVersion" != "$version" -a "${fullVersion%[.-]*}" != "$fullVersion" ]; do
			versionAliases+=( $fullVersion )
			fullVersion="${fullVersion%[.-]*}"
		done
		versionAliases+=(
			$version
			${aliases[$version]:-}
		)

		variantAliases=( "${versionAliases[@]/%/-$variant}" )
		if [ "$variant" = "$defaultAlpineVariant" ]; then
			variantAliases+=( "${versionAliases[@]/%/-alpine}" )
		fi
		variantAliases=( "${variantAliases[@]//latest-/}" )

		sharedTags=()
		if [ "$variant" = "$defaultDebianVariant" ] || [[ "$variant" == 'windowsservercore'* ]]; then
			sharedTags+=( "${versionAliases[@]}" )
		fi

		case "$v" in
			windows/*) variantArches='windows-amd64' ;;
			*) variantArches="$(parentArches "$version" "$dir")" ;;
		esac

		echo
		echo "Tags: $(join ', ' "${variantAliases[@]}")"
		if [ "${#sharedTags[@]}" -gt 0 ]; then
			echo "SharedTags: $(join ', ' "${sharedTags[@]}")"
		fi
		cat <<-EOE
			Architectures: $(join ', ' $variantArches)
			GitCommit: $commit
			Directory: $dir
		EOE
		[[ "$v" == windows/* ]] && echo "Constraints: $variant"
	done
done
