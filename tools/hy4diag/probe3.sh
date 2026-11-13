#!/bin/bash
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
M=/tmp/sysm
mountpoint -q $M || mount -o loop,ro $IMG $M
echo "===== bootstrap linker / libs ====="
ls -la $M/system/bin/bootstrap/ 2>&1 | head -10
ls -la $M/system/lib64/bootstrap/ 2>&1 | head -20
echo "===== ld.config ====="
ls -l $M/system/etc/ld.config* 2>&1 | head
ls -l $M/system/etc/*ld.config* 2>&1 | head
echo "===== real bionic anywhere? ====="
find $M -maxdepth 4 -name 'linker64' 2>/dev/null | head
find $M -maxdepth 5 -name 'libc.so' 2>/dev/null | head -10
echo "===== init strings: bootstrap / apex / fstab ====="
strings -a $M/system/bin/init | grep -iE 'bootstrap|/apex|apexd' | head -30
echo "--- fstab/mount hallmarks ---"
strings -a $M/system/bin/init | grep -iE 'first_stage|fstab|force_normal|skip_initramfs|switch_root' | head -40
echo "===== system/bin/bootstrap dir contents in system_ext? ====="
ls $M/system_ext/bin/ | head -20
echo "===== /system/etc/ramdisk ====="
ls -l $M/system/etc/ramdisk/ 2>&1 | head
echo "===== props of interest ====="
grep -E '^(ro.build.flavor|ro.system.build.version|ro.apex.updatable|ro.boot.dynamic_partitions|ro.virtual_ab|ro.fsverity|ro.crypto|ro.gsid|ro.gsi|ro.build.system_root_image|ro.treble)' $M/system/build.prop $M/system_ext/build.prop 2>/dev/null | head -20
umount $M
echo "===== HyperOS vendor.img selinux files ====="
V=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/vendor.img
rm -rf /tmp/vvend && mkdir -p /tmp/vvend
fsck.erofs --extract=/tmp/vvend --force --overwrite --include-path=etc/selinux $V 2>&1 | tail -3
find /tmp/vvend -maxdepth 4 | head -30
echo "===== HyperOS odm.img? (selinux) - skip ====="
echo DONE3
