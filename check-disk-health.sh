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
EMAIL_SUBJECT_PREFIX="$HOSTNAME BTRFS - "

LOG_FILE="/var/log/btrfs-scrub.log"

TMP_OUTPUT="/tmp/btrfs-scrub.$$.out"

[[ $(whoami) = "root" ]] || { sudo $0 "$@"; exit 0; }

# redirect all stdout to log file
exec >> $LOG_FILE

# mail header to the file
echo "From: "$AuthUserName" <$AuthUser>" > $TMP_OUTPUT
echo "To: $AdminEMail" >> $TMP_OUTPUT
echo "Subject: $EMAIL_SUBJECT_PREFIX Scrub Job Completed" >> $TMP_OUTPUT
echo "" >> "$TMP_OUTPUT"
# timestamp the job
echo "btrfs scrub job started on `date -Iseconds`" | tee -a $TMP_OUTPUT
echo "----------------------------------------" | tee -a $TMP_OUTPUT

# for each btrfs type system mounted, scrub and record output
while read d m t x
do
  [[ $t != "btrfs" ]] && continue
  >&2 echo "To be scrubbed: $m" # for direct invocations
done < <( cat /proc/mounts | sort -u -k1,1)


while read d m t x
do
  [[ $t != "btrfs" ]] && continue
  echo "[`date -Iseconds`] scrubbing $m" | tee -a $TMP_OUTPUT
  >&2 echo "[`date -Iseconds`] scrubbing $m" # for direct invocations
  btrfs scrub start -Bd $m | tee -a $TMP_OUTPUT
  echo "" | tee -a $TMP_OUTPUT
done < <( cat /proc/mounts | sort -u -k1,1)

echo "----------------------------------------" | tee -a $TMP_OUTPUT
echo "btrfs scrub job finished on `date -Iseconds`" | tee -a $TMP_OUTPUT

>&2 echo "Sending mail to $AdminEMail" # for direct invocations

curl \
  --ssl-reqd \
  --mail-from "<$AuthUser>" \
  --mail-rcpt "<$AdminEMail>" \
  --url "smtps://$mailhub" \
  --user "$AuthUser:$AuthPass" \
  --upload-file "$TMP_OUTPUT" \
  && rm "$TMP_OUTPUT" || true


echo "[`date -Iseconds`] Scrub job ended."
exit 0;
