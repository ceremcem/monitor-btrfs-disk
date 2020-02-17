#!/bin/bash
set -u
safe_source () { [[ ! -z ${1:-} ]] && source $1; _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; _sdir=$(dirname "$(readlink -f "$0")"); }; safe_source

#######################################################
# This is a helper script to be used in a systemd timer
# or cron job to scrub all mounted btrfs filessytems
#
# $Author: gbrks
# $Modified: ceremcem
# $Revision 0.11
# $Date: 2015.05.15
#

# Import the credentials
[[ ! -f ${1:-} ]] && { echo "Usage: $(basename $0) /path/to/credentials"; exit 1; }
safe_source $1

AuthUserName="Disk Monitor"
EMAIL_SUBJECT_PREFIX="$HOSTNAME"

TMP_OUTPUT="/tmp/mail-test.txt"

# mail header to the file
echo "From: "$AuthUserName" <$AuthUser>" > $TMP_OUTPUT
echo "To: $AdminEMail" >> $TMP_OUTPUT
echo "Subject: Testing" >> $TMP_OUTPUT
echo "" >> "$TMP_OUTPUT"
# timestamp the job

>&2 echo "Sending mail to $AdminEMail" # for direct invocations

curl \
  --ssl-reqd \
  --mail-from "<$AuthUser>" \
  --mail-rcpt "<$AdminEMail>" \
  --url "smtps://$mailhub" \
  --user "$AuthUser:$AuthPass" \
  --upload-file "$TMP_OUTPUT" \
  -v \
  && rm "$TMP_OUTPUT" || true

exit 0;

