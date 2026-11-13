#!/bin/bash
M=/tmp/sysm
mkdir -p $M
mountpoint -q $M || mount -o loop,ro /mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img $M
for f in system/lib64/lib_cust_mount_helper.so system/lib64/lib_opcust_mount_helper.so system/lib64/soc_flags_lib_cc.so system/lib64/libPlatformProperties.so system/lib64/libvendorsupport.so; do
  echo "########## $f ($(stat -c%s $M/$f 2>/dev/null) bytes) ##########"
  strings -a $M/$f 2>/dev/null | grep -aiE 'exit|_exit|abort|kill|reboot|/system/bin/sh|/bin/sh|exec|popen|system\(|getprop|property|cust|opcust|/proc/|/sys/' | head -14
  echo "--- NEEDED ---"
  readelf -d $M/$f 2>/dev/null | grep NEEDED | sed 's/.*\[//;s/\]//' | tr '\n' ' '; echo
done
echo "########## does init link a shell-ish helper? ##########"
strings -a $M/system/bin/init | grep -aE '/system/bin/sh|/bin/sh|sh -c|popen|system\(' | head -8
echo "########## ld.config in image (double check) ##########"
ls -la $M/system/etc/ | grep -iE 'ld|linker' | head
echo "########## /system/etc top count ##########"
ls $M/system/etc | wc -l
umount $M
echo DONE_H
