#!/bin/bash
#
# Description
# ------------
# This script resumes any interrupted scrub operations.
# Mark the state as "dirty" with "--mark" switch.
#
set -eu
safe_source () { [[ ! -z ${1:-} ]] && source $1; _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; _sdir=$(dirname "$(readlink -f "$0")"); }; safe_source

show_help(){
    cat <<HELP

    Resumes any interrupted scrub operations on all mounted Btrfs filesystems.

    $(basename $0) [options]

    Options:

        --mark [disk]        : Only mark the disk (or all mounted Btrfs filesystems) as dirty, exit immediately.
        --start              : Start scrubbing on all filesystems and wait till finish.

HELP
}

die(){
    >&2 echo
    >&2 echo "$@"
    exit 1
}

help_die(){
    >&2 echo
    >&2 echo "$@"
    show_help
    exit 1
}


TMP_OUTPUT="/tmp/btrfs-scrub.out"

echostamp(){
    echo "`date -Iseconds`: $@"
}

_kill(){
    exit 0
}

scrub_status(){
    local fs=$1
    btrfs scrub status $fs | grep -E "^Status" | awk -F: '{print $2}' | tr -d ' '
}


scrub_start(){
    local fs=$1
    local curr=$(scrub_status $fs)
    if [[ "$curr" != "running" ]]; then
        echostamp "Starting scrub task for $fs"
        btrfs scrub start -B $fs && \
            btrfs scrub status -d $fs >> $TMP_OUTPUT  &
    else
        echostamp "Scrub job is already running for $fs. Skipping."
    fi
}

scrub_mark_dirty(){
    local fs=$1
    if [[ "$(scrub_status $fs)" == "" || "$(scrub_status $fs)" == "finished" ]]; then
        # Eligible to start a scrub
        echostamp "Marking $fs as dirty."
        btrfs scrub start $fs
        while sleep 1; do
            [[ $(scrub_status $fs) == "running" ]] && break
        done
        btrfs scrub cancel $fs
    else
        echostamp "State of $fs is already non-clean. Skipping."
    fi
}

scrub_resume(){
    local fs=$1
    local curr=$(scrub_status $fs)
    if [[ "$curr" = "running" ]]; then
        echostamp "Scrub is already running for $fs"
    elif [[ "$curr" = "aborted" ]] || [[ "$curr" = "interrupted" ]]; then
        echostamp "Continuing interrupted scrub for $fs"
        btrfs scrub resume -B $fs 1>/dev/null 2>&1 \
            && btrfs scrub status -d $fs \
            >> $TMP_OUTPUT &
    else
        echostamp "Nothing to do for $fs"
    fi
}

[[ $(whoami) = "root" ]] || { sudo $0 "$@"; exit 0; }

# Parse command line arguments
# ---------------------------
# Initialize parameters
only_mark=false
do_run=false
# ---------------------------
args_backup=("$@")
args=()
_count=1
while [ $# -gt 0 ]; do
    key="${1:-}"
    case $key in
        -h|-\?|--help|'')
            show_help    # Display a usage synopsis.
            exit
            ;;
        # --------------------------------------------------------
        --mark) 
            only_mark=true
            [[ -n ${2:-} ]] && { scrub_mark_dirty $2; exit 0; }
            ;;
        --start)
            do_run=true
            ;;
        # --------------------------------------------------------
        -*) # Handle unrecognized options
            help_die "Unknown option: $1"
            ;;
        *)  # Generate the new positional arguments: $arg1, $arg2, ... and ${args[@]}
            if [[ ! -z ${1:-} ]]; then
                declare arg$((_count++))="$1"
                args+=("$1")
            fi
            ;;
    esac
    [[ -z ${1:-} ]] && break || shift
done; set -- "${args_backup[@]}"
# Use $arg1 in place of $1, $arg2 in place of $2 and so on, 
# "$@" is in the original state,
# use ${args[@]} for new positional arguments  

>&2 echo "Using output file: $TMP_OUTPUT"

# Process all apparent devices
while read fs; do
    if $only_mark; then
        scrub_mark_dirty $fs
    elif $do_run; then
        scrub_start $fs
    else # resume 
        scrub_resume $fs
    fi
done < <( cat /proc/mounts | awk '$3 == "btrfs" {print $1}' | uniq )

if $only_mark; then
    echostamp "All available devices are marked as dirty. Exiting."
    exit 0
fi

if ! $do_run; then
    # cancel all running scrubs on interrupt
    trap _kill EXIT
fi

wait # for any scrub operation

# Send report if available
if [[ -f $TMP_OUTPUT ]]; then
    $_sdir/send-email.sh $TMP_OUTPUT
fi

echostamp "Done."
