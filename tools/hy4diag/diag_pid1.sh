#!/bin/bash
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img

echo "########## A. init: PID 1 checks ##########"
for f in /root/ib2/init $D/mi6/rd/init; do
  echo "--- $(basename $f) ($(stat -c%s $f) bytes)"
  strings -a $f | grep -aiE 'PID 1|pid 1|getpid|must be run|run as init|InitCanReboot|reboot system now|Failed to open /dev/|SetStdioToDevNull|InitKernelLogging|restorecon' | head -12
done

echo "########## B. image: does /vendor/etc/selinux really exist? ##########"
mkdir -p /mnt/chk
mountpoint -q /mnt/chk || mount -o loop,ro $IMG /mnt/chk
echo "--- /vendor ---"; ls -la /mnt/chk/vendor/ | head -8
echo "--- /vendor/etc ---"; ls -la /mnt/chk/vendor/etc/ 2>&1 | head -5
echo "--- /vendor/etc/selinux ---"; ls /mnt/chk/vendor/etc/selinux 2>&1 | head -5
echo "--- counts ---"
echo "vendor=$(ls /mnt/chk/vendor/etc/selinux 2>/dev/null | wc -l) product=$(ls /mnt/chk/product/etc/selinux 2>/dev/null | wc -l) vendor_odm=$(ls /mnt/chk/vendor/odm/etc/selinux 2>/dev/null | wc -l)"
echo "--- inode types ---"
stat -c '%F %n' /mnt/chk/vendor /mnt/chk/vendor/etc /mnt/chk/vendor/etc/selinux 2>&1
echo "--- dangling? /vendor/etc is symlink? ---"
readlink -f /mnt/chk/vendor 2>&1; readlink -f /mnt/chk/vendor/etc 2>&1
umount /mnt/chk

echo "########## C. how big is /vendor in the fs (block usage) ##########"
dumpe2fs -h $IMG 2>/dev/null | grep -E 'Free blocks|Block count'

echo "########## D. mi6 image: where are their vendor policies? ##########"
echo "(their image: /vendor was empty too -> check where selinux came from)"
echo DONE_A
