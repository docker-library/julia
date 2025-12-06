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

# TODO scrape LTS version track from somewhere so we can rename the "1.x" folder of LTS to just "lts" and have this script deal with it completely
# see also https://github.com/docker-library/julia/issues/92

# https://julialang.org/downloads/#json_release_feed
# https://julialang-s3.julialang.org/bin/versions.json
# https://julialang-s3.julialang.org/bin/versions-schema.json
juliaVersions="$(
	wget -qO- 'https://julialang-s3.julialang.org/bin/versions.json' | jq -c '
		[
			to_entries[]
			| .key as $version
			| .value
			| {
				$version,
				stable,
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
		]

		| (
			def scan_version:
				[
					scan("[0-9]+|[^0-9]+|^$")
					| tonumber? // .
				]
			;

			sort_by(.version | scan_version)
			| reverse

			| first(.[] | select(.stable) | .version) as $stable
			| first(.[] | select(.stable | not) | .version) as $rc
			| if ($stable | scan_version) >= ($rc | scan_version) then
				# if latest "stable" is newer than the latest pre-release, remove *all* the pre-releases
				map(select(.stable))
			else . end
		)
	'
)"

for version in "${versions[@]}"; do
	export version

	if \
		! doc="$(jq <<<"$juliaVersions" -ce '
			first(.[] | select(
				if IN(env.version; "stable", "rc") then
					.stable == (env.version == "stable")
				else
					.stable and (
						.version
						| startswith(env.version + ".")
					)
				end
			))
		')" \
		|| ! fullVersion="$(jq <<<"$doc" -r '.version')" \
		|| [ -z "$fullVersion" ] \
	; then
		echo >&2 "warning: cannot find full version for $version"
		json="$(jq <<<"$json" -c '.[env.version] = null')"
		continue
	fi

	echo "$version: $fullVersion"

	json="$(jq <<<"$json" -c --argjson doc "$doc" '.[env.version] = (
		$doc
		| del(.stable)
		| .variants = ([
			"trixie",
			"bookworm",
			if .arches | keys | any(startswith("alpine-")) then
				"3.23",
				"3.22",
				empty
				| "alpine" + .
			else empty end,
			if .arches | has("windows-amd64") then # TODO "windows-arm64v8" someday? 👀
				"ltsc2025",
				"ltsc2022",
				empty
				| "windows/servercore-" + .
			else empty end
		])
	)')"
done

jq <<<"$json" '
	to_entries
	| sort_by(
		.key as $k
		# match the order on https://julialang.org/downloads/manual-downloads/
		| [ "stable", "lts" ] | (index($k) // length + ([ "rc" ] | (index($k) // -1) + 1)), $k
		# (this is a compressed clone of https://github.com/docker-library/meta-scripts/blob/af716438af4178d318a03f4144668d76c9c8222f/sort.jq#L29-L52)
	)
	| from_entries
' > versions.json
