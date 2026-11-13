#!/bin/bash
set -e
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
R=/root/ramdisk_diag
OUT=$D/bootbuild_diag

aarch64-linux-gnu-gcc -static -O2 -o /root/shim_diag $D/shim_diag.c 2>&1 | grep -v warn_unused || true
ls -l /root/shim_diag; file /root/shim_diag | cut -c1-90

rm -rf $R && mkdir -p $R && cd $R
cpio -idm --no-absolute-filenames < $D/ib/ramdisk.cpio 2>/dev/null
rm -f init; cp /root/shim_diag init; chmod 0750 init
mkdir -p pol/vendor pol/product pol/odm newroot
cp -a /root/pol/vendor/.  pol/vendor/
cp -a /root/pol/product/. pol/product/
cp -a /root/pol/odm/.     pol/odm/
echo "pol=$(find pol -type f | wc -l) size=$(du -sh . | cut -f1)"

find . -print0 | cpio --null -o -H newc --owner=0:0 > $D/ramdisk_diag.cpio 2>/dev/null
ls -l $D/ramdisk_diag.cpio

rm -rf $OUT && mkdir -p $OUT
cp $D/b1/kernel $OUT/kernel
cp $D/b1/kernel_dtb $OUT/kernel_dtb
cp $D/b1/header $OUT/header
cp $D/ramdisk_diag.cpio $OUT/ramdisk.cpio
echo READY_DIAG
