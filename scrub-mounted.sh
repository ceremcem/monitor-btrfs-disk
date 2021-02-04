#!/bin/bash
#
# Description
# ------------
# This script resumes any interrupted scrub operations.
# Mark the state as "dirty" with "--mark" switch.
#
set -eu
safe_source () { [[ ! -z ${1:-} ]] && source $1; _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; _sdir=$(dirname "$(readlink -f "$0")"); }; safe_source

[[ $(whoami) = "root" ]] || { sudo $0 "$@"; exit 0; }

TMP_OUTPUT="/tmp/btrfs-scrub.out"

echostamp(){
    echo "`date -Iseconds`: $@"
}

_kill(){
    $_sdir/cancel-scrubs.sh
    sleep 2
    exit 0
}

scrub_status(){
    btrfs scrub status $fs | grep -E "^Status" | awk -F: '{print $2}' | tr -d ' '
}

scrub_mark_dirty(){
    btrfs scrub start $fs
    while sleep 1; do
        [[ $(scrub_status $fs) == "running" ]] && break
    done
    btrfs scrub cancel $fs
}

scrub_resume(){
    local fs=$1
    local curr=$(scrub_status $fs)
    if [[ "$curr" = "running" ]]; then
        echostamp "Scrub is already running for $fs"
    elif [[ "$curr" = "aborted" ]] || [[ "$curr" = "interrupted" ]]; then
        echostamp "Continuing interrupted scrub for $fs"
        btrfs scrub resume -Bd $fs && \
            btrfs scrub status -d $fs >> $TMP_OUTPUT &
    else
        echostamp "Nothing to do for $fs"
    fi
}

[[ "${1:-}" == "--mark" ]] && trigger_new=true || trigger_new=false

# Process all apparent devices
while read fs; do
    if $trigger_new; then
        echostamp "Marking $fs as dirty."
        scrub_mark_dirty $fs
    else
        scrub_resume $fs
    fi
done < <( cat /proc/mounts | awk '$3 == "btrfs" {print $1}' | uniq )

if $trigger_new; then
    echostamp "All available devices are marked as dirty. Exiting."
    exit 0
fi

# cancel all running scrubs on interrupt
trap _kill EXIT

wait # for any scrub operation
echostamp "All scrub operations are completed."

scrub_error_status(){
    local result=$1
    if cat $result | grep -i "Error summary:" | grep -v "no errors found" -q; then
        echo "ERRORS FOUND"
    else
        echo "Success."
    fi
}

# Send report if available
if [[ -f $TMP_OUTPUT ]]; then
    echostamp "Found $TMP_OUTPUT, sending via email."
    source $_sdir/credentials.sh

    mail=$(mktemp)
    AuthUserName="Disk Monitor"

    echo "From: "$AuthUserName" <$AuthUser>" > $mail
    echo "To: $AdminEMail" >> $mail
    echo "Subject: $HOSTNAME - BTRFS Scrub Job: $(scrub_error_status $TMP_OUTPUT)" >> $mail
    echo "" >> "$mail"
    cat $TMP_OUTPUT >> $mail

    curl \
      --ssl-reqd \
      --mail-from "<$AuthUser>" \
      --mail-rcpt "<$AdminEMail>" \
      --url "smtps://$mailhub" \
      --user "$AuthUser:$AuthPass" \
      --upload-file "$mail" \
      && { rm "$TMP_OUTPUT"; rm $mail; } || true

    echostamp "Mail is sent to $AdminEMail"
fi

