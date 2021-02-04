#!/bin/bash
set -eu -o pipefail
safe_source () { [[ ! -z ${1:-} ]] && source $1; _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; _sdir=$(dirname "$(readlink -f "$0")"); }; safe_source
# end of bash boilerplate


show_help(){
    cat <<HELP

    $(basename $0) [options] --for-server|--for-laptop

    Options:

        --for-laptop      : Mark system state dirty on every PERIOD. 
        --for-server      : Run Btrfs scrub on every PERIOD
        --period          : systemd service period. Default: "weekly"

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

# Parse command line arguments
# ---------------------------
# Initialize parameters
exe_switch=
service_type=forking
PERIOD="weekly"  # "*-*-* 22:30:00"
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
        --for-laptop)
            exe_switch="--mark"
            ;;
        --for-server)
            exe_switch="--start"
            service_type=idle      # like "simple", but wait till idle
            ;;
        --period) shift
            PERIOD=$1
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

[[ $(whoami) = "root" ]] || { sudo $0 "$@"; exit 0; }

if ! hash curl 2> /dev/null; then 
    echo "Installing dependencies if missing."
    apt-get install curl
    echo "Dependencies installed."
fi

[[ -z $exe_switch ]] && help_die "Profile is required."

EXECUTABLE_PATH="$_sdir/scrub-mounted.sh"

SERVICE_NAME="btrfs-scrub-mounted"
SERVICE_PATH="/etc/systemd/system"

service_file="$SERVICE_PATH/$SERVICE_NAME.service"
echo "Installing $service_file"
cat << SERVICE > "$service_file"
[Unit]
Description=Run 'btrfs scrub' on all mounted disks.

[Service]
User=root
Type=$service_type
ExecStart=$EXECUTABLE_PATH $exe_switch

SERVICE

timer_file="$SERVICE_PATH/$SERVICE_NAME.timer"
echo "installing $timer_file"
cat << TIMER > "$timer_file"
[Unit]
Description=Run 'btrfs scrub' on all mounted disks.

[Timer]
OnCalendar=$PERIOD
Persistent=true

[Install]
WantedBy=timers.target

TIMER

echo "+++ Installed systemd timers."

## installing systemd services + timers
systemctl daemon-reload
systemctl disable "$SERVICE_NAME.service" # for backwards compatibilty
systemctl enable "$SERVICE_NAME.timer"
systemctl start "$SERVICE_NAME.timer"

echo
echo "To trigger $SERVICE_NAME immediately, run the following command:"
echo
echo "    sudo systemctl start $SERVICE_NAME"
echo
echo "To see the logs:"
echo
echo "    sudo journalctl -u $SERVICE_NAME"
echo
