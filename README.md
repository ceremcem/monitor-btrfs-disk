# Monitor BTRFS Disk 

Periodically checks the data integrity on the disk and reports the results by e-mail. 


# Install 

1. Copy `credentials.sh.example` and modify accordingly.
2. `./install.sh`

# Other Examinations:

## Finding the corrupted files 

Output is instantaneous after `btrfs scrub`, however paths are relative to their subvolumes, thus it's hard to identify which file belongs to which subvolume:

```
sudo btrfs scrub start -B /path/to/mountpoint # -> you should already have done that
./get-corrupted-files.sh
```

> See https://unix.stackexchange.com/q/557213/65781

## Determine Physical Disk Health 

```
sudo smartctl -t long -C /dev/sdX
sudo badblocks -v /dev/sdX
```

TODO: Document how to interpret the `smartctl` results.
TODO2: Add the conversation link from BTRFS mailing list with the subject "Is it logical to use a disk that scrub fails but smartctl succeeds?"

## "DRDY ERR" check:

```
sudo dmesg | grep "DRDY ERR"
```
