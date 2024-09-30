#!/usr/bin/env bash
set -Eeuo pipefail

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

# sort version numbers with highest first
IFS=$'\n'; set -- $(sort -rV <<<"$*"); unset IFS

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		files="$(
			git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						if ($i ~ /^--from=/) {
							next
						}
						print $i
					}
				}
			'
		)"
		fileCommit Dockerfile $files
	)
}

getArches() {
	local repo="$1"; shift
	local officialImagesBase="${BASHBREW_LIBRARY:-https://github.com/docker-library/official-images/raw/HEAD/library}/"

	local parentRepoToArchesStr
	parentRepoToArchesStr="$(
		find -name 'Dockerfile' -exec awk -v officialImagesBase="$officialImagesBase" '
				toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|.*\/.*)(:|$)/ {
					printf "%s%s\n", officialImagesBase, $2
				}
			' '{}' + \
			| sort -u \
			| xargs -r bashbrew cat --format '["{{ .RepoName }}:{{ .TagName }}"]="{{ join " " .TagEntry.Architectures }}"'
	)"
	eval "declare -g -A parentRepoToArches=( $parentRepoToArchesStr )"
}
getArches 'julia'

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

declare -A latest=(
	#[1]='1.9'
	#[latest]='1.9'
	#[rc]='1.10-rc'
)

for version; do
	export version

	if ! fullVersion="$(jq -er '.[env.version] | if . then .version else empty end' versions.json)"; then
		continue
	fi

	variants="$(jq -r '.[env.version].variants | map(@sh) | join(" ")' versions.json)"
	eval "variants=( $variants )"

	versionAliases=(
		$fullVersion
		$version
	)

	aliases=()
	if [ "$version" = "${version%-rc}" ]; then
		if [[ "$version" =~ [0-9]+[.][0-9]+ ]]; then
			aliases+=( "${version%%.*}" latest ) # "1", "latest"
		fi
	else
		aliases+=( rc )
	fi
	for a in "${aliases[@]}"; do
		if [ -z "${latest[$a]:-}" ]; then
			latest[$a]="$version"
			versionAliases+=( "$a" )
		fi
	done

	defaultDebianVariant="$(jq -r '
		.[env.version].variants
		| map(select(
			startswith("alpine")
			or startswith("windows/")
			| not
		))
		| .[0]
	' versions.json)"
	defaultAlpineVariant="$(jq -r '
		.[env.version].variants
		| map(select(
			startswith("alpine")
		))
		| .[0]
	' versions.json)"

	for v in "${variants[@]}"; do
		dir="$version/$v"
		[ -f "$dir/Dockerfile" ] || continue
		variant="$(basename "$v")"
		export variant

		commit="$(dirCommit "$dir")"

		variantAliases=( "${versionAliases[@]/%/-$variant}" )
		sharedTags=()
		case "$variant" in
			"$defaultDebianVariant" | windowsservercore-*)
				sharedTags=( "${versionAliases[@]}" )
				;;
			"$defaultAlpineVariant")
				variantAliases+=( "${versionAliases[@]/%/-alpine}" )
				;;
		esac
		variantAliases=( "${variantAliases[@]//latest-/}" )

		for windowsShared in windowsservercore nanoserver; do
			if [[ "$variant" == "$windowsShared"* ]]; then
				sharedTags+=( "${versionAliases[@]/%/-$windowsShared}" )
				sharedTags=( "${sharedTags[@]//latest-/}" )
				break
			fi
		done

		constraints=
		case "$v" in
			windows/*)
				variantArches="$(jq -r '
					.[env.version].arches
					| keys[]
					| select(startswith("windows-"))
					| select(. != "windows-i386") # TODO "windows-arm64v8" someday? 👀
				' versions.json | sort)"
				constraints="$variant"
				;;

			*)
				variantParent="$(awk 'toupper($1) == "FROM" { print $2; exit }' "$dir/Dockerfile")"
				variantArches="${parentRepoToArches[$variantParent]:-}"
				variantArches="$(
					comm -12 \
						<(
							jq -r '
								.[env.version].arches
								| keys[]
								| if env.variant | startswith("alpine") then
									if startswith("alpine-") then
										ltrimstr("alpine-")
									else
										empty
									end
								else . end
							' versions.json | sort
						) \
						<(xargs -n1 <<<"$variantArches" | sort)
				)"
				;;
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
		[ -z "$constraints" ] || {
			echo "Constraints: $constraints";
			echo 'Builder: classic' # no Windows support in BuildKit (yet)
		}
	done
done
