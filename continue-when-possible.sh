#!/bin/bash
safe_source () { [[ ! -z ${1:-} ]] && source $1; _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; _sdir=$(dirname "$(readlink -f "$0")"); }; safe_source
set -eu 

# (see https://github.com/ceremcem/on-idle)
[[ -z ${1:-} ]] && { echo "Usage: $(basename $0) path/to/on-idle.sh"; exit 1; }
on_idle=$1
sudo $on_idle 00:01:00 $_sdir/scrub-mounted.sh
