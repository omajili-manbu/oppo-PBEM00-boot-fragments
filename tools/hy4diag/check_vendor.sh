#!/bin/bash
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
mkdir -p /mnt/chk
mountpoint -q /mnt/chk || mount -o loop,ro $IMG /mnt/chk
echo "===== 1. what is /vendor in the ORIGINAL image (before my edit)? ====="
echo "--- current /vendor tree depth 3 ---"
find /mnt/chk/vendor -maxdepth 3 2>/dev/null | head -20
echo "--- is there a vendor dir at image root? ---"
ls -ld /mnt/chk/vendor
echo "--- stat nlink (dir with subdirs) ---"
stat -c 'nlink=%h %n' /mnt/chk/vendor /mnt/chk/vendor/etc /mnt/chk/vendor/etc/selinux
echo
echo "===== 2. was /vendor a MOUNT POINT marker in original ROM? ====="
echo "--- check HyperOS original system.img /vendor ---"
mkdir -p /mnt/orig
mountpoint -q /mnt/orig || mount -o loop,ro /mnt/e/play/MIO-KITCHEN/r17HyperOS4/system.img /mnt/orig 2>/dev/null
ls -la /mnt/orig/vendor 2>&1 | head -5
echo "--- original vendor entry count: $(ls -A /mnt/orig/vendor 2>/dev/null | wc -l)"
echo
echo "===== 3. fsck image for the vendor dir inodes ====="
echo "--- count inodes under /vendor ---"
find /mnt/chk/vendor 2>/dev/null | wc -l
echo "--- e2fsck ---"
umount /mnt/orig 2>/dev/null
umount /mnt/chk 2>/dev/null
e2fsck -f -n $IMG 2>&1 | tail -4
echo
echo "===== 4. re-mount and verify with debugfs (bypasses VFS) ====="
debugfs -R "ls -l /vendor" $IMG 2>/dev/null | head -6
debugfs -R "ls -l /vendor/etc" $IMG 2>/dev/null | head -6
debugfs -R "ls -l /vendor/etc/selinux" $IMG 2>/dev/null | head -6
echo DONE_V
