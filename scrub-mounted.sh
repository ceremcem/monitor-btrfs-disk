#!/bin/bash
set -eu
safe_source () { [[ ! -z ${1:-} ]] && source $1; _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; _sdir=$(dirname "$(readlink -f "$0")"); }; safe_source

[[ $(whoami) = "root" ]] || { sudo $0 "$@"; exit 0; }

TMP_OUTPUT="/tmp/btrfs-scrub.out"
start_flag="/tmp/btrfs-scrub-required.txt"

echostamp(){
    echo "`date -Iseconds`: $@"
}

_kill(){
    $_sdir/cancel-scrubs.sh
    exit 0
}

scrub_resume_or_start(){
    local resume_only=false
    [[ "$1" = "--resume-only" ]] && { resume_only=true; shift; }
    local fs=$1
    local curr=`btrfs scrub status $fs | grep -E "^Status" | awk -F: '{print $2}' | tr -d ' '`
    if [[ "$curr" = "running" ]]; then
        echostamp "Scrub is already running for $fs"
    elif [[ "$curr" = "aborted" ]] || [[ "$curr" = "interrupted" ]]; then
        echostamp "Continuing interrupted scrub for $fs"
        btrfs scrub resume -Bd $fs && \
            btrfs scrub status -d $fs >> $TMP_OUTPUT &
    else
        if [[ "$resume_only" = false ]]; then
            echostamp "Starting scrub job for $fs" 
            btrfs scrub start -Bd $fs && \
                btrfs scrub status -d $fs >> $TMP_OUTPUT &
        else
            echostamp "Not starting a scrub job for $fs" 
        fi
    fi
}

if [[ "${1:-}" == "--start" || -f "$start_flag" ]]; then
    start=true
    resume_only=
else
    start=false
    resume_only="--resume-only"
fi

min_uptime=10
_uptime=$(awk '{print int($1/60)}' /proc/uptime)
if [[ $_uptime -lt $min_uptime ]]; then
    echostamp "Skipping because uptime is lower than $min_uptime min." | tee -a $_sdir/log.txt
    [[ "$start" = true ]] && date > "$start_flag"
else
    [[ -f "$start_flag" ]] && rm "$start_flag"
    while read m; do
        scrub_resume_or_start $resume_only "$m"
    done < <( cat /proc/mounts | awk '$3 == "btrfs" {print $1}' | uniq )
fi

if [[ -f $TMP_OUTPUT ]]; then
    echostamp "Found $TMP_OUTPUT, sending via email."
    source $_sdir/credentials.sh

    mail=$(mktemp)
    AuthUserName="Disk Monitor"

    echo "From: "$AuthUserName" <$AuthUser>" > $mail
    echo "To: $AdminEMail" >> $mail
    echo "Subject: $HOSTNAME - BTRFS Scrub Job Completed" >> $mail
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

if [[ -n $resume_only ]]; then
    trap _kill EXIT 
    sleep Infinity
fi
