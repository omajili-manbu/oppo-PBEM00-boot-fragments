#!/bin/bash
set -e
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
M=/mnt/ours

echo "=== 1. rebuild DTB (vendor disabled) ==="
cd $K
make O=out dtbs > /tmp/dt2.log 2>&1 && echo DTBS_OK || { tail -20 /tmp/dt2.log; exit 1; }
DTB=$K/out/arch/arm64/boot/dts/18081/sdm670.dtb
ls -l "$DTB"
dtc -I dtb -O dts "$DTB" 2>/dev/null | sed -n '/fstab {/,/^			};/p' | head -24

echo
echo "=== 2. add modern fstab to image /vendor/etc/fstab.qcom ==="
mkdir -p $M
mountpoint -q $M || mount -o loop,rw $IMG $M || true
mountpoint -q $M && echo "image mounted rw"
mkdir -p $M/vendor/etc
cat > $M/vendor/etc/fstab.qcom <<'EOF'
# PBEM00 HyperOS4-on-4.9 bring-up fstab (A17 syntax)
# <src> <mnt_point> <type> <mnt_flags> <fs_mgr_flags>
/dev/block/platform/soc/1d84000.ufshc/by-name/system  /system  ext4  ro,barrier=1,discard  wait
EOF
chmod 0644 $M/vendor/etc/fstab.qcom
ls -l $M/vendor/etc/
echo "--- content ---"; cat $M/vendor/etc/fstab.qcom
sync
cd /; umount $M
e2fsck -f -n $IMG 2>&1 | tail -2
echo "image sha: $(sha256sum $IMG | cut -c1-24)"

echo
echo "=== 3. stage + repack boot (same kernel cd33545c + new DTB) ==="
OUT=$D/bootbuild_kw2
rm -rf $OUT || true
mkdir -p $OUT
cp $K/out/arch/arm64/boot/Image $OUT/kernel
cp "$DTB" $OUT/kernel_dtb
cp $D/b1/header $OUT/header
cp $D/ramdisk_a1b.cpio $OUT/ramdisk.cpio
ls -l $OUT
echo "kernel sha: $(sha256sum $OUT/kernel | cut -c1-24) (want cd33545c)"
echo "dtb sha:    $(sha256sum $OUT/kernel_dtb | cut -c1-24)"
echo READY_KW2
