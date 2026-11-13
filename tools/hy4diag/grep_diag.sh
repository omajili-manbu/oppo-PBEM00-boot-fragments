#!/bin/bash
M=/tmp/sysm
mkdir -p $M
mountpoint -q $M || mount -o loop,ro /mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img $M
echo "===== who contains the arc4random warning string? ====="
for f in system/bin/bootstrap/linker64 system/bin/init system/lib64/bootstrap/libc.so system/lib64/libbase.so; do
  n=$(strings -a $M/$f 2>/dev/null | grep -c 'MADV_WIPEONFORK failed')
  echo "$f : $n"
done
echo "===== ld.config references in bootstrap linker ====="
strings -a $M/system/bin/bootstrap/linker64 | grep -iE 'ld\.config|linkerconfig' | head -12
echo "===== linker64 fatal-ish messages ====="
strings -a $M/system/bin/bootstrap/linker64 | grep -aE 'CANNOT LINK|not found|unsupported|Unsupported|kernel|EABI|min_sdk|not compatible|invalid' | head -25
echo "===== init: 127 / exit / fatal-ish ====="
strings -a $M/system/bin/init | grep -aiE 'exitcode|reboot,|InitFatalReboot|Failed to load SELinux|watchdog|SecondStage|second_stage' | head -20
echo "===== does image ship ld.config anywhere? ====="
find $M -name '*ld.config*' -o -name 'ld.config*' 2>/dev/null | head
echo "===== init's NEEDED (bootstrap link check) ====="
readelf -d $M/system/bin/init 2>/dev/null | grep -c NEEDED
umount $M
echo DONE_G
