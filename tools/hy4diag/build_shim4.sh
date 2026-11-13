#!/bin/bash
set -e
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img

echo "=== compile shim4 ==="
aarch64-linux-gnu-gcc -static -O2 -o /root/shim4 $D/shim4.c 2>&1 | grep -vE 'warn_unused|^\s|^In function|\^' || true
ls -l /root/shim4

echo "=== verify image patch state ==="
mkdir -p /mnt/chk
mountpoint -q /mnt/chk || mount -o loop,ro $IMG /mnt/chk
od -A x -t x1 -j $((0x11C76C)) -N 4 /mnt/chk/system/bin/init
echo "vendor selinux: $(ls /mnt/chk/vendor/etc/selinux 2>/dev/null | wc -l)"
echo "product selinux: $(ls /mnt/chk/product/etc/selinux 2>/dev/null | wc -l)"
echo "vendor/odm selinux: $(ls /mnt/chk/vendor/odm/etc/selinux 2>/dev/null | wc -l)"
umount /mnt/chk

echo "=== build ramdisk: shim4 + ROM init_boot content ==="
R=/root/rd_shim4
rm -rf $R && mkdir -p $R && cd $R
cpio -idm --no-absolute-filenames < $D/ib/ramdisk.cpio 2>/dev/null
rm -f init
cp /root/shim4 init && chmod 0750 init
mkdir -p apex bootstrap-apex linkerconfig
echo "  contents: $(ls | tr '\n' ' ')"
find . -print0 | cpio --null -o -H newc --owner=0:0 > $D/ramdisk_shim4.cpio 2>/dev/null
ls -l $D/ramdisk_shim4.cpio

OUT=$D/bootbuild_shim4
rm -rf $OUT && mkdir -p $OUT
cp $D/b1/kernel $OUT/kernel
cp $D/b1/kernel_dtb $OUT/kernel_dtb
cp $D/b1/header $OUT/header
cp $D/ramdisk_shim4.cpio $OUT/ramdisk.cpio
echo READY_SHIM4
