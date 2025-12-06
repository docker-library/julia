#!/usr/bin/env bash
set -Eeuo pipefail

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

# get the most recent commit which modified any files related to a build context
commit="$(git log -1 --format='format:%H' HEAD -- '[^.]*/**')"

getArches() {
	local repo="$1"; shift
	local oiBase="${BASHBREW_LIBRARY:-https://github.com/docker-library/official-images/raw/HEAD/library}/"

	# grab supported architectures for each parent image, except self-referential
	jq --raw-output \
		--arg oiBase "$oiBase" \
		--arg repo "$repo" '
			include "shared";
			[
				from(.[].variants[])
				| select(startswith($repo + ":") or index("/") | not)
			]
			| unique[]
			| $oiBase + .
		' versions.json \
		| xargs -r bashbrew cat --format '{ {{ join ":" .RepoName  .TagName | json }}: {{ json .TagEntry.Architectures }} }' \
		| jq --compact-output --slurp 'add'
}
parentsArches="$(getArches 'julia')"

selfCommit="$(git log -1 --format='format:%H' HEAD -- "$self")"
cat <<-EOH
# this file is generated via https://github.com/docker-library/julia/blob/$selfCommit/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon),
             Joseph Ferguson <yosifkit@gmail.com> (@yosifkit)
GitRepo: https://github.com/docker-library/julia.git
GitCommit: $commit
EOH

exec jq \
	--raw-output \
	--argjson parentsArches "$parentsArches" \
	--from-file generate-stackbrew-library.jq \
	versions.json \
	--args -- "$@"
