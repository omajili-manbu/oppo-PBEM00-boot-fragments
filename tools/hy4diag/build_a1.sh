#!/bin/bash
set -e
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
DTB=$K/out/arch/arm64/boot/dts/18081/sdm670.dtb
R=/root/rd_a1

echo "=== ramdisk: ROM init_boot content + /dev nodes + fstab ==="
rm -rf $R && mkdir -p $R && cd $R
cpio -idm --no-absolute-filepaths < $D/ib/ramdisk.cpio 2>/dev/null || cpio -idm --no-absolute-filenames < $D/ib/ramdisk.cpio 2>/dev/null
ls -l init | head -2

# pre-create device nodes so init can log even without devtmpfs
mkdir -p dev dev/pts dev/socket
mknod dev/null    c 1 3 2>/dev/null || true
mknod dev/zero    c 1 5 2>/dev/null || true
mknod dev/full    c 1 7 2>/dev/null || true
mknod dev/random  c 1 8 2>/dev/null || true
mknod dev/urandom c 1 9 2>/dev/null || true
mknod dev/kmsg    c 1 11 2>/dev/null || true
mknod dev/console c 5 1 2>/dev/null || true
mknod dev/tty     c 5 0 2>/dev/null || true
mknod dev/ptmx    c 5 2 2>/dev/null || true
chmod 666 dev/null dev/zero dev/full dev/random dev/urandom dev/tty dev/ptmx 2>/dev/null || true
chmod 600 dev/kmsg dev/console 2>/dev/null || true

# fallback fstab (DT fstab takes precedence; keep consistent)
cat > fstab.qcom <<'EOF'
system /system ext4 ro,barrier=1,discard wait
vendor /vendor ext4 ro,barrier=1,async_discard wait
EOF
echo "--- ramdisk ---"; ls; echo "--- dev ---"; ls -l dev | head

find . -print0 | cpio --null -o -H newc --owner=0:0 > $D/ramdisk_a1.cpio 2>/dev/null
ls -l $D/ramdisk_a1.cpio

echo "=== stage boot components ==="
OUT=$D/bootbuild_a1
rm -rf $OUT && mkdir -p $OUT
cp $D/b1/kernel $OUT/kernel
cp "$DTB" $OUT/kernel_dtb
cp $D/b1/header $OUT/header
cp $D/ramdisk_a1.cpio $OUT/ramdisk.cpio
ls -l $OUT
echo "dtb sha: $(sha256sum "$DTB" | cut -c1-24)"
echo READY_A1
