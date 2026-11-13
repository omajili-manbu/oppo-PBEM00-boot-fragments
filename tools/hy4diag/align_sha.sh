#!/bin/bash
set -e
SYS=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
VEN='/mnt/c/Users/QWE12/Desktop/vendor_A17fix.img'
MS=/mnt/sys
MV=/mnt/vfix

mountpoint -q $MV || mount -o loop,ro "$VEN" $MV
mountpoint -q $MS || mount -o loop,rw $SYS $MS || true
mountpoint -q $MS && echo "system rw ok"

echo "=== vendor precompiled sha files ==="
for f in $MV/etc/selinux/precompiled_sepolicy.*.sha256; do
  echo "  $(basename $f): $(cat $f)"
done

echo
echo "=== align system sha files ==="
cp -f $MV/etc/selinux/precompiled_sepolicy.plat_sepolicy_and_mapping.sha256 \
      $MS/system/etc/selinux/plat_sepolicy_and_mapping.sha256
cp -f $MV/etc/selinux/precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256 \
      $MS/system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256
cp -f $MV/etc/selinux/precompiled_sepolicy.product_sepolicy_and_mapping.sha256 \
      $MS/product/etc/selinux/product_sepolicy_and_mapping.sha256
echo "--- after ---"
for f in $MS/system/etc/selinux/plat_sepolicy_and_mapping.sha256 \
         $MS/system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256 \
         $MS/product/etc/selinux/product_sepolicy_and_mapping.sha256; do
  echo "  $(echo $f | sed 's|/mnt/sys||'): $(cat $f)"
done

echo
echo "=== security_load_policy patch still in place? ==="
od -A x -t x4 -j $((0x12fc4)) -N 8 $MS/system/lib64/libselinux.so

sync
cd /; umount $MS
e2fsck -f -n $SYS 2>&1 | tail -2
echo "system sha: $(sha256sum $SYS | cut -c1-24)"
echo SHA_ALIGN_DONE
