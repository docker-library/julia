include "shared";

to_entries
| map_values(select(.)) # ignore nulls ("rc" post-GA)

| (
	# our entries are in precedence order, so loop over them in order and assign "generic" tags like "1" to the first entry that might use them
	reduce .[] as $v ({};
		.[
			$v.value.version
			| if $v.key == "rc" then
				# pre-releases get an intentionally limited set of tags
				[
					., # "1.13.0-alpha2"
					(split(".")[0:2] | join(".") + "-rc"), # "1.13-rc"
					"rc",
					empty
				]
			else
				# TODO should we add an explicit "stable" alias?  for us, that's currently spelled "latest" and that's probably good enough?
				# (see similar TODO in "versions.sh" about "lts")
				split(".")
				| [
					foreach .[] as $c ([]; . += [ $c ])
					| join(".")
				]
				| reverse + [ "" ]
			end
			| .[]
		] //= $v.key
	)
	# now that object is backwards ({ "1": "stable", "1.X": "stable" }), so let's reduce it back the other way ({ "stable": [ "1", "1.X" ] }) so lookups are trivial below
	| reduce to_entries[] as $e ({}; .[$e.value] += [ $e.key ])
) as $versionsTags

| (first(.[].value.variants[] | select(startswith("alpine") or startswith("windows/") | not)) // "") as $latestDebian
| (first(.[].value.variants[] | select(startswith("alpine"))) // "") as $latestAlpine

| .[]
| .key as $key
| .value

# only the major versions asked for "./generate-stackbrew-library.sh X Y ..."
| if $ARGS.positional != [] then
	select(IN($key; $ARGS.positional[]))
else . end

| $versionsTags[$key] as $versionTags

| .variants[] as $variant # "trixie", "alpine3.22", "windows/servercore-ltsc2025", etc

# Tags:
| [
	(
		$variant
		| if startswith("windows/servercore-") then
			sub("/"; "")
		elif startswith("windows/nanoserver-") then
			ltrimstr("windows/")
		else
			.
		end
	),

	if $variant == $latestAlpine then
		"alpine"
	else empty end,

	empty

	| $versionTags[] as $versionTag
	| [ $versionTag, . | select(. != "") ]
	| join("-")
	| if . == "" then "latest" else . end
] as $tags

# SharedTags:
| [
	(
		$variant
		| if startswith("windows/servercore-") then
			"windowsservercore",
			""
		elif startswith("windows/nanoserver-") then
			"nanoserver"
		elif . == $latestDebian then
			""
		else empty end
	),

	empty

	| $versionTags[] as $versionTag
	| [ $versionTag, . | select(. != "") ]
	| join("-")
	| if . == "" then "latest" else . end
] as $sharedTags

# Architectures:
| (
	.arches
	| keys_unsorted

	| if $variant | startswith("alpine") then
		map(
			select(startswith("alpine-"))
			| ltrimstr("alpine-")
		)
	else . end

	| (
		$parentsArches[from($variant)]
		// if $variant | startswith("windows/") then
			[ "windows-amd64" ] # TODO windows-arm64v8 someday?
		else [] end
	) as $parentArches
	| . - (. - $parentArches) # intersection
) as $arches

| (
	"",
	"Tags: \($tags | join(", "))",
	if $sharedTags != [] then "SharedTags: \($sharedTags | join(", "))" else empty end,
	"Directory: \($key)/\($variant)",
	"Architectures: \($arches | join(", "))",
	(
		$variant
		| if startswith("windows/") then
			split("-")[-1] as $winver
			| [
				if startswith("windows/nanoserver-") then
					"nanoserver-" + $winver
				else empty end,
				"windowsservercore-" + $winver,
				empty
			]
			| "Constraints: " + join(", ")
		else empty end
	),
	empty
)
