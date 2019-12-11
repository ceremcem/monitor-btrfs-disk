#!/bin/bash

PERIOD="weekly"


show_help(){
    cat <<HELP
    $(basename $0) /path/to/executable /path/to/credentials
HELP
    exit 1
}

[[ -x $1 ]] || show_help
[[ -f $2 ]] || show_help

EXECUTABLE_PATH="$(realpath $1)"
CREDENTIALS="$(realpath $2)"

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

# Install dependencies if missing
hash curl 2> /dev/null || apt-get install curl

## installing systemd services + timers
systemctl daemon-reload
systemctl enable "$SERVICE_NAME.service"
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
