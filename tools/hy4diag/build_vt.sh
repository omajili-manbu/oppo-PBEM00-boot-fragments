#!/bin/bash
set -e
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710

echo "=== 1. rebuild DTB (vendor ENABLED again) ==="
cd $K
make O=out dtbs > /tmp/dt3.log 2>&1 && echo DTBS_OK || { tail -20 /tmp/dt3.log; exit 1; }
DTB=$K/out/arch/arm64/boot/dts/18081/sdm670.dtb
ls -l "$DTB"
dtc -I dtb -O dts "$DTB" 2>/dev/null | sed -n '/fstab {/,/^			};/p' | head -22

echo
echo "=== 2. stage shim7 boot with NEW kernel + NEW dtb ==="
OUT=$D/bootbuild_vt
rm -rf $OUT || true
mkdir -p $OUT
cp $K/out/arch/arm64/boot/Image $OUT/kernel
cp "$DTB" $OUT/kernel_dtb
cp $D/b1/header $OUT/header
cp $D/ramdisk_shim7.cpio $OUT/ramdisk.cpio
ls -l $OUT
echo "kernel sha: $(sha256sum $OUT/kernel | cut -c1-24) (want cd33545c)"
echo "dtb sha:    $(sha256sum $OUT/kernel_dtb | cut -c1-24)"
echo "ramdisk has shim7: $(cpio -it < $OUT/ramdisk.cpio 2>/dev/null | grep -c ' init$')"
echo READY_VT
