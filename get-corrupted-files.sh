#!/bin/bash

sub_list=/tmp/subvolume-list-of-root.txt

sudo btrfs sub list / > $sub_list

while read a; do
    root_id=$(echo $a | awk '{print $16}' | sed -r 's/,//')
    rel_path=$(echo $a | sed -r 's/.*path:\s(.+)\)/\1/g')
    subvol_path=$(cat $sub_list | awk '$2 == '"$root_id"' {print $9}')
    [[ -z $subvol_path ]] && subvol_path="????"
    echo "/$subvol_path/$rel_path"
done < <( sudo journalctl --output cat | grep 'BTRFS .* i/o error' | sort | uniq )
