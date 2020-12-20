#!/bin/bash
set -eu -o pipefail
safe_source () { [[ ! -z ${1:-} ]] && source $1; _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; _sdir=$(dirname "$(readlink -f "$0")"); }; safe_source
# end of bash boilerplate

# Description
# ----------
# This is `btrfs scrub` supervisor that cancels any running
# scrub operations

[[ $(whoami) = "root" ]] || { sudo $0 "$@"; exit 0; }

while read -r path; do
    [[ -z $path ]] && { echo "No running scrub operations found."; break; }
    echo -n "Found scrub on \"$path\", cancelling:  "
    btrfs scrub cancel "$path"
done <<< $(ps -ef | grep "[b]trfs scrub" | awk '{print $NF}' | sort | uniq)
