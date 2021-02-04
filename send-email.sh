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
    echo "No file found as $mail"
else
    source $_sdir/credentials.sh
    echo "Found $mail_body, sending $AdminEMail"

    mail=`mktemp -q /tmp/scrub-result.XXXXXX`
    AuthUserName="Disk Monitor"

    echo "From: "$AuthUserName" <$AuthUser>" > $mail
    echo "To: $AdminEMail" >> $mail
    echo "Subject: $HOSTNAME - BTRFS Scrub Job: $(scrub_error_status $mail_body)" >> $mail
    echo "" >> "$mail"
    cat $mail_body >> $mail

    if timeout 30 curl \
      --ssl-reqd \
      --mail-from "<$AuthUser>" \
      --mail-rcpt "<$AdminEMail>" \
      --url "smtps://$mailhub" \
      --user "$AuthUser:$AuthPass" \
      --upload-file "$mail"; then

        rm "$mail_body"
        rm $mail
        echo "`date -u`: Mail is sent to $AdminEMail"
    else
        echo
        echo "`date -u`: Failed to send mail."
        exit 1
    fi
fi

