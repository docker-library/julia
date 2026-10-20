#!/bin/sh
set -eu

# first arg is `-e` or `--some-option` (docker run julia -e '42')
# ... is a "*.jl" file                 (docker run -v ...:/my/file.jl:ro julia /my/file.jl)
# ... or there are no args
if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ] || [ "${1%.jl}" != "$1" ]; then
	exec julia "$@"
fi

exec "$@"
