#!/bin/bash
set -eu -o pipefail
safe_source () { [[ ! -z ${1:-} ]] && source $1; _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; _sdir=$(dirname "$(readlink -f "$0")"); }; safe_source
# end of bash boilerplate

PERIOD="weekly"


show_help(){
    cat <<HELP
    $(basename $0) /path/to/credentials
HELP
    exit 1
}

[[ -f ${1:-} ]] || show_help

EXECUTABLE_PATH="$_sdir/check-disk-health.sh"
CREDENTIALS="$(realpath $1)"

[[ $(whoami) = "root" ]] || { sudo $0 "$@"; exit 0; }


SERVICE_NAME="check-disk-health"
SERVICE_PATH="/etc/systemd/system"

service_file="$SERVICE_PATH/$SERVICE_NAME.service"
echo "Installing $service_file"
cat << SERVICE > "$service_file"
[Unit]
Description=btrfs scrub

[Service]
User=root
Type=simple
ExecStart=$EXECUTABLE_PATH $CREDENTIALS

[Install]
WantedBy=timers.target

SERVICE

timer_file="$SERVICE_PATH/$SERVICE_NAME.timer"
echo "installing $timer_file"
cat << TIMER > "$timer_file"
[Unit]
Description=Runs btrfs scrub on all discs $PERIOD

[Timer]
OnCalendar=$PERIOD
Persistent=true

[Install]
WantedBy=timers.target

TIMER

service_file="$SERVICE_PATH/$SERVICE_NAME-supervisor.service"
echo "installing scrub supervisor"
cat << EOL > "$service_file"
[Unit]
Description=Pause running btrfs scrubs on suspend
Before=suspend.target

[Service]
Type=oneshot
ExecStart=$_sdir/scrub-supervisor.sh

[Install]
WantedBy=suspend.target
EOL




# Install dependencies if missing
hash curl 2> /dev/null || apt-get install curl

## installing systemd services + timers
systemctl daemon-reload
systemctl enable "$SERVICE_NAME.service"
systemctl enable "$SERVICE_NAME.timer"
systemctl enable "$SERVICE_NAME-supervisor.service"
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
