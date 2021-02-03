#!/bin/bash
set -eu -o pipefail
safe_source () { [[ ! -z ${1:-} ]] && source $1; _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; _sdir=$(dirname "$(readlink -f "$0")"); }; safe_source
# end of bash boilerplate

[[ $(whoami) = "root" ]] || { sudo $0 "$@"; exit 0; }

echo "Installing dependencies if missing."
hash curl 2> /dev/null || apt-get install curl
echo "Dependencies installed."

PERIOD="weekly"
#PERIOD="*-*-* 22:30:00"
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
Type=forking
ExecStart=$EXECUTABLE_PATH --mark

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
