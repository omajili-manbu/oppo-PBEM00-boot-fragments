#!/bin/bash
set -e
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
DTB=$K/out/arch/arm64/boot/dts/18081/sdm670.dtb
R=/root/rd_a1b

echo "=== ramdisk A1b: Mi6 static init + dev nodes + fstab ==="
rm -rf $R && mkdir -p $R && cd $R
cpio -idm --no-absolute-filenames < $D/ib/ramdisk.cpio 2>/dev/null
rm -f init
cp /root/init_mi6_static init && chmod 0750 init
ls -l init
file init | cut -c1-80

mkdir -p dev dev/pts dev/socket
mknod dev/null    c 1 3  2>/dev/null || true
mknod dev/zero    c 1 5  2>/dev/null || true
mknod dev/full    c 1 7  2>/dev/null || true
mknod dev/random  c 1 8  2>/dev/null || true
mknod dev/urandom c 1 9  2>/dev/null || true
mknod dev/kmsg    c 1 11 2>/dev/null || true
mknod dev/console c 5 1  2>/dev/null || true
mknod dev/tty     c 5 0  2>/dev/null || true
mknod dev/ptmx    c 5 2  2>/dev/null || true
chmod 666 dev/null dev/zero dev/full dev/random dev/urandom dev/tty dev/ptmx 2>/dev/null || true
chmod 600 dev/kmsg dev/console 2>/dev/null || true

cat > fstab.qcom <<'EOF'
system /system ext4 ro,barrier=1,discard wait
vendor /vendor ext4 ro,barrier=1,async_discard wait
EOF

find . -print0 | cpio --null -o -H newc --owner=0:0 > $D/ramdisk_a1b.cpio 2>/dev/null
ls -l $D/ramdisk_a1b.cpio
echo "--- archive dev check ---"
cpio -itv < $D/ramdisk_a1b.cpio 2>/dev/null | grep -c '^crw'

OUT=$D/bootbuild_a1b
rm -rf $OUT && mkdir -p $OUT
cp $D/b1/kernel $OUT/kernel
cp "$DTB" $OUT/kernel_dtb
cp $D/b1/header $OUT/header
cp $D/ramdisk_a1b.cpio $OUT/ramdisk.cpio
ls -l $OUT
echo READY_A1B
