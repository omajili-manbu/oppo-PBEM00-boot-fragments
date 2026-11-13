#!/bin/bash
set -e
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
DTB=$K/out/arch/arm64/boot/dts/18081/sdm670.dtb
R=/root/rd_shim7

echo "=== compile shim7 ==="
aarch64-linux-gnu-gcc -static -O2 -o /root/shim7 $D/shim7.c 2>&1 | grep -E 'error' | head; ls -l /root/shim7

echo "=== ramdisk: shim7 + ROM init_boot content + dev nodes ==="
rm -rf $R && mkdir -p $R && cd $R
cpio -idm --no-absolute-filenames < $D/ib/ramdisk.cpio 2>/dev/null
rm -f init; cp /root/shim7 init; chmod 0750 init
mkdir -p dev dev/pts dev/socket
for n in "null 1 3 0666" "zero 1 5 0666" "full 1 7 0666" "random 1 8 0666" "urandom 1 9 0666" "kmsg 1 11 0600" "console 5 1 0600" "tty 5 0 0666" "ptmx 5 2 0666"; do
  set -- $n; mknod dev/$1 c $2 $3 2>/dev/null || true; chmod $4 dev/$1 2>/dev/null || true
done
find . -print0 | cpio --null -o -H newc --owner=0:0 > $D/ramdisk_shim7.cpio 2>/dev/null
ls -l $D/ramdisk_shim7.cpio

OUT=$D/bootbuild_shim7
rm -rf $OUT && mkdir -p $OUT
cp $D/b1/kernel $OUT/kernel
cp "$DTB" $OUT/kernel_dtb
cp $D/b1/header $OUT/header
cp $D/ramdisk_shim7.cpio $OUT/ramdisk.cpio
echo READY_SHIM7
