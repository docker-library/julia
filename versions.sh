#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

# https://julialang.org/downloads/#json_release_feed
# https://julialang-s3.julialang.org/bin/versions.json
# https://julialang-s3.julialang.org/bin/versions-schema.json
juliaVersions="$(
	wget -qO- 'https://julialang-s3.julialang.org/bin/versions.json' | jq -c '
		[
			to_entries[]
			| .key as $version
			| .value
			| (
				($version | sub("^(?<m>[0-9]+[.][0-9]+).*$"; "\(.m)"))
				+ if .stable then "" else "-rc" end
			) as $major
			| {
				version: $version,
				major: $major,
				arches: (.files | map(
					# map values from the julia versions-schema.json to bashbrew architecture values
					# (plus some extra fiddly bits for Alpine)
					{
						mac: "darwin",
						winnt: "windows",
						linux: (
							if .triplet | endswith("-musl") then
								"alpine"
							else
								"linux"
							end
						),
						freebsd: "freebsd",
					}[.os] as $os
					| {
						x86_64: "amd64",
						i686: "i386",
						powerpc64le: "ppc64le",
						aarch64: "arm64v8",
						armv7l: "arm32v7",
					}[.arch] as $arch
					| if $os == null or $arch == null then empty
					elif .kind != (if $os == "windows" then "installer" else "archive" end) then empty
					else {
						key: (
							if $os == "linux" then "" else $os + "-" end
							+ $arch
						),
						value: {
							url: .url,
							sha256: .sha256,
						},
					} end
				) | from_entries),
			}
		] | sort_by([.major, .version] | map(split("[.-]"; "") | map(if test("^[0-9]+$") then tonumber else . end)))
	'
)"

for version in "${versions[@]}"; do
	export version

	if \
		! doc="$(jq <<<"$juliaVersions" -c '
			[ .[] | select(.major == env.version) ][-1]
		')" \
		|| ! fullVersion="$(jq <<<"$doc" -r '.version')" \
		|| [ -z "$fullVersion" ] \
	; then
		echo >&2 "warning: cannot find full version for $version"
		continue
	fi

	echo "$version: $fullVersion"

	json="$(jq <<<"$json" -c --argjson doc "$doc" '.[env.version] = (
		$doc
		| del(.major)
		| .variants = ([
			"bullseye",
			"buster",
			if .arches | keys | any(startswith("alpine-")) then
				"3.15",
				"3.14"
				| "alpine" + .
			else empty end,
			if .arches | has("windows-amd64") then
				"ltsc2022",
				"1809",
				"ltsc2016"
				| "windows/windowsservercore-" + .
			else empty end
		])
	)')"
done

jq <<<"$json" -S . > versions.json
