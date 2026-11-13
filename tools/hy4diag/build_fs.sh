#!/bin/bash
set -e
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag

echo "=== 1. odm policy into image (/vendor/odm/etc/selinux) ==="
mkdir -p /mnt/ours
mountpoint -q /mnt/ours || mount -o loop,rw $IMG /mnt/ours || true
mkdir -p /mnt/ours/vendor/odm/etc/selinux
cp -a /root/pol/odm/. /mnt/ours/vendor/odm/etc/selinux/
echo "  /vendor/odm/etc/selinux: $(ls /mnt/ours/vendor/odm/etc/selinux | wc -l) files"
sync
cd /; umount /mnt/ours

echo "=== 2. build first-stage ramdisk (ROM init_boot content + fstab) ==="
R=/root/ramdisk_fs
rm -rf $R && mkdir -p $R && cd $R
cpio -idm --no-absolute-filenames < $D/ib/ramdisk.cpio 2>/dev/null
printf 'system /system ext4 ro,barrier=1 wait\n' > fstab.qcom
cat fstab.qcom
echo "  ramdisk: $(ls | tr '\n' ' ')"

find . -print0 | cpio --null -o -H newc --owner=0:0 > $D/ramdisk_fs.cpio 2>/dev/null
ls -l $D/ramdisk_fs.cpio

echo "=== 3. stage + repack ==="
OUT=$D/bootbuild_fs
rm -rf $OUT && mkdir -p $OUT
cp $D/b1/kernel $OUT/kernel
cp $D/b1/kernel_dtb $OUT/kernel_dtb
cp $D/b1/header $OUT/header
cp $D/ramdisk_fs.cpio $OUT/ramdisk.cpio
ls -la $OUT
echo READY_FS
