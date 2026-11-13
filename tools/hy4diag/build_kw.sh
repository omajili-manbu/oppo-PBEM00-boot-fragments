#!/bin/bash
set -e
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
IMG=$K/out/arch/arm64/boot/Image
DTB=$K/out/arch/arm64/boot/dts/18081/sdm670.dtb
VMLINUX=$K/out/vmlinux

echo "=== 1. artifacts ==="
ls -l "$IMG" "$DTB"
[ -f "$VMLINUX" ] && ls -l "$VMLINUX" || echo "(vmlinux missing)"

echo
echo "=== 2. static verify: copy_one_pte has VM_WIPEONFORK test ==="
SM=$K/out/System.map
if [ -f "$SM" ]; then
  A=$(grep -m1 ' copy_one_pte$' "$SM" | awk '{print $1}')
  echo "copy_one_pte @ 0x$A"
  if [ -n "$A" ]; then
    aarch64-linux-gnu-objdump -d --start-address=0x$A --stop-address=$((0x$A + 0x120)) "$VMLINUX" 2>/dev/null \
      | grep -nE 'tbz|tbnz|tst|and' | grep -E '#23|#0x800000|#0x8000000' | head -5
    echo "--- (looking for bit-23 test = VM_WIPEONFORK 0x00800000) ---"
    aarch64-linux-gnu-objdump -d --start-address=0x$A --stop-address=$((0x$A + 0x120)) "$VMLINUX" 2>/dev/null | tail -n +7 | head -18
  fi
fi

echo
echo "=== 3. static verify: madvise_behavior knows 18/19 ==="
if [ -f "$SM" ]; then
  B=$(grep -m1 ' madvise_behavior$' "$SM" | awk '{print $1}')
  echo "madvise_behavior @ 0x$B"
  if [ -n "$B" ]; then
    aarch64-linux-gnu-objdump -d --start-address=0x$B --stop-address=$((0x$B + 0x400)) "$VMLINUX" 2>/dev/null \
      | grep -E 'mov\s+w[0-9]+, #0x1[23]|cmp\s+w[0-9]+, #0x1[23]' | head -6
  fi
fi

echo
echo "=== 4. stage + repack (kernel + new DTB + Mi6-init ramdisk) ==="
OUT=$D/bootbuild_kw
rm -rf $OUT || true
mkdir -p $OUT
cp "$IMG" $OUT/kernel
cp "$DTB" $OUT/kernel_dtb
cp $D/b1/header $OUT/header
cp $D/ramdisk_a1b.cpio $OUT/ramdisk.cpio
ls -l $OUT
echo "kernel sha: $(sha256sum $OUT/kernel | cut -c1-24)"
echo "dtb sha:    $(sha256sum $OUT/kernel_dtb | cut -c1-24)"
echo READY_KW
