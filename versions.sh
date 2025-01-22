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
	rcVersion="${version%-rc}"
	export version rcVersion

	if \
		! doc="$(jq <<<"$juliaVersions" -ce '
			[ .[] | select(.major == env.version) ][-1]
		')" \
		|| ! fullVersion="$(jq <<<"$doc" -r '.version')" \
		|| [ -z "$fullVersion" ] \
	; then
		echo >&2 "warning: cannot find full version for $version"
		continue
	fi

	echo "$version: $fullVersion"

	if [ "$rcVersion" != "$version" ] && gaFullVersion="$(jq <<<"$json" -er '.[env.rcVersion] | if . then .version else empty end')"; then
		# Julia pre-releases have always only been for .0, so if our pre-release now has a relevant GA, it should go away 👀
		# $ wget -qO- 'https://julialang-s3.julialang.org/bin/versions.json' | jq 'keys_unsorted[]' -r | grep -E '[^0]-'
		# just in case, we'll also do a version comparison to make sure we don't have a pre-release that's newer than the relevant GA
		latestVersion="$({ echo "$fullVersion"; echo "$gaFullVersion"; } | sort -V | tail -1)"
		if [[ "$fullVersion" == "$gaFullVersion"* ]] || [ "$latestVersion" = "$gaFullVersion" ]; then
			# "x.y.z-rc1" == x.y.z*
			json="$(jq <<<"$json" -c 'del(.[env.version])')"
			continue
		fi
	fi

	json="$(jq <<<"$json" -c --argjson doc "$doc" '.[env.version] = (
		$doc
		| del(.major)
		| .variants = ([
			"bookworm",
			"bullseye",
			if .arches | keys | any(startswith("alpine-")) then
				"3.21",
				"3.20",
				empty
				| "alpine" + .
			else empty end,
			if .arches | has("windows-amd64") then
				"ltsc2025",
				"ltsc2022",
				"1809",
				empty
				| "windows/windowsservercore-" + .
			else empty end
		])
	)')"

	# make sure pre-release versions have a placeholder for GA
	if [ "$version" != "$rcVersion" ]; then
		json="$(jq <<<"$json" -c '.[env.rcVersion] //= null')"
	fi
done

jq <<<"$json" -S . > versions.json
