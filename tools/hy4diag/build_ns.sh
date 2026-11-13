#!/bin/bash
set -e
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
IMG=$K/out/arch/arm64/boot/Image
DTB=$K/out/arch/arm64/boot/dts/18081/sdm670.dtb

echo "=== 1. build rc ==="
grep -E '^(build_rc|dtbs_rc)=' /tmp/ns_build.log
echo "errors: $(grep -c 'error:' /tmp/ns_build.log)"

echo
echo "=== 2. SELinux really gone from Image? ==="
for s in 'SELinux: ' 'selinuxfs' 'security_load_policy' 'policydb' 'avc:  denied' 'SMACK'; do
  printf '  %-24s %s\n' "$s" "$(strings -a $IMG | grep -cF "$s")"
done
echo "  kernel version: $(strings -a $IMG | grep -m1 'Linux version')"
ls -l $IMG "$DTB"

echo
echo "=== 3. stage + repack boot_hy4_ns.img ==="
OUT=$D/bootbuild_ns
rm -rf $OUT || true
mkdir -p $OUT
cp $IMG $OUT/kernel
cp "$DTB" $OUT/kernel_dtb
cp $D/b1/header $OUT/header
cp $D/ramdisk_a1b.cpio $OUT/ramdisk.cpio
ls -l $OUT
echo "kernel sha: $(sha256sum $OUT/kernel | cut -c1-24)"
echo "dtb sha:    $(sha256sum $OUT/kernel_dtb | cut -c1-24)"
echo READY_NS
