#!/bin/bash
set -u
safe_source () { [[ ! -z ${1:-} ]] && source $1; _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; _sdir=$(dirname "$(readlink -f "$0")"); }; safe_source

TMP_OUTPUT="/tmp/send-mail-test"

err=
case ${1:-} in
    --error)
        err="Some error"
        ;;
    --success)
        ;;
    -h|--help|'')
        echo "Usage: $(basename $0) --error|--success"
        exit 1
        ;;
    *)
        echo "Unrecognized option."
        exit 1
        ;;
esac

cat << EOL > $TMP_OUTPUT
UUID:             SOME-UUID-HERE

Scrub device /dev/sdx (id 1) history
Scrub resumed:    Thu Feb  4 07:06:51 2021
Status:           aborted
Duration:         1:21:32
Total to scrub:   846.02GiB
Rate:             92.46MiB/s
Error summary:    ${err:-no errors found}
EOL

$_sdir/send-email.sh $TMP_OUTPUT
