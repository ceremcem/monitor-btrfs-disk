#!/bin/bash
set -eu
safe_source () { [[ ! -z ${1:-} ]] && source $1; _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; _sdir=$(dirname "$(readlink -f "$0")"); }; safe_source

mail_body=$1

scrub_error_status(){
    local result=$1
    if cat $result | grep -i "Error summary:" | grep -v "no errors found" -q; then
        echo "ERRORS FOUND"
    else
        echo "Success."
    fi
}

# Send report if available
if [[ ! -f $mail_body ]]; then
    echo "No file found as $mail_body"
elif [[ ! -s $mail_body ]]; then
    echo "$mail_body seems empty, skipping."
else
    source $_sdir/credentials.sh
    echo "Found $mail_body, sending $AdminEMail"

    mail="/tmp/scrub-result.mail"
    AuthUserName="Disk Monitor"

    echo "From: "$AuthUserName" <$AuthUser>" > $mail
    echo "To: $AdminEMail" >> $mail
    echo "Subject: $HOSTNAME - BTRFS Scrub Job: $(scrub_error_status $mail_body)" >> $mail
    echo "" >> "$mail"
    cat $mail_body >> $mail

    if [[ -n ${Proxy:-} ]]; then
        echo "------------------------------------"
        echo "Using SOCKS5 proxy: $Proxy"
        echo "------------------------------------"
        proxy_str="-x socks5h://$Proxy"
    fi

    if timeout 30 curl \
        ${proxy_str:-} \
        --ssl-reqd \
        --mail-from "<$AuthUser>" \
        --mail-rcpt "<$AdminEMail>" \
        --url "smtps://$mailhub" \
        --user "$AuthUser:$AuthPass" \
        --upload-file "$mail"; 
    then

        rm "$mail_body"
        rm $mail
        echo "`date -u`: Mail is sent to $AdminEMail"
    else
        rm $mail
        echo
        echo "`date -u`: Failed to send mail."
        exit 1
    fi
fi

