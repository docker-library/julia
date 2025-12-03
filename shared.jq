def from($variant):
	$variant
	| if startswith("alpine") then
		"alpine:\(ltrimstr("alpine"))"
	elif startswith("windows/") then
		"mcr.microsoft.com/\(sub("-"; ":"))" # mcr.microsoft.com/windows/servercore:ltsc2025, ...
	else
		"debian:\(.)-slim"
	end
;
