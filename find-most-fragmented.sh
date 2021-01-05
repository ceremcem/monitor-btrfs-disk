#!/bin/bash
set -u

# taken from: https://helmundwalter.de/en/blog/btrfs-finding-and-fixing-highly-fragmented-files/
num=30
fragment_limit="500"
for d in "$@"; do 
    >&2 echo "Searching for most fragmented $num files in $d" 
    find $d -xdev -type f \
        | xargs filefrag 2>/dev/null \
        | sed 's/^\(.*\): \([0-9]\+\) extent.*/\2 \1/' \
        | awk -F ' ' '$1 > '"$fragment_limit" \
        | sort -n -r \
        | head -${num}
done

