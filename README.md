# Monitor BTRFS Disk 

Periodically checks the data integrity on the disk and reports the results by e-mail. 


# Install 

1. Copy `credentials.sh.example` and modify accordingly.
2. `./install.sh`

# Usage

### Continue when idle

```
on-idle.sh 00:02:00 ./scrub-mounted.sh
```

See https://github.com/ceremcem/on-idle


# Other Examinations:

## Finding the corrupted files 

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

TODO: Document how to interpret the `smartctl` results. <br /> 
TODO2: Add the conversation link from BTRFS mailing list with the subject "Is it logical to use a disk that scrub fails but smartctl succeeds?"

## "DRDY ERR" check:

```
sudo dmesg | grep "DRDY ERR"
```
