#!/bin/bash
set -e
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
STOCK=/mnt/e/play/MIO-KITCHEN/r17org/system.img
VEND=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/vendor.img
M=/mnt/ours
S=/mnt/stock

echo "=== 1. copy mapping 26..29 from ColorOS10 stock into image ==="
mkdir -p $M $S
mountpoint -q $M || mount -o loop,rw $IMG $M || true
mountpoint -q $S || mount -o loop,ro $STOCK $S || true
mountpoint -q $M && echo "image rw OK"
mountpoint -q $S && echo "stock ro OK"
ls $M/system/etc/selinux/mapping/ | tr '\n' ' '; echo
for v in 26.0 27.0 28.0 29.0; do
  for suf in "" ".compat"; do
    src="$S/system/etc/selinux/mapping/${v}${suf}.cil"
    [ -f "$src" ] || continue
    cp -f "$src" "$M/system/etc/selinux/mapping/${v}${suf}.cil"
    echo "  copied ${v}${suf}.cil ($(stat -c%s "$src") bytes)"
  done
done
echo "--- after ---"; ls $M/system/etc/selinux/mapping/ | tr '\n' ' '; echo
sync

echo
echo "=== 2. baseline vendor policy into ramdisk /pol/vendor (HyperOS own) ==="
rm -rf /root/pol && mkdir -p /root/pol/vendor
mkdir -p /root/vm
erofsfuse $VEND /root/vm 2>/dev/null && sleep 1
if [ -d /root/vm/etc/selinux ]; then
  cp -a /root/vm/etc/selinux/. /root/pol/vendor/
  echo "vendor policy files: $(ls /root/pol/vendor | wc -l)"
  cat /root/pol/vendor/plat_sepolicy_vers.txt 2>/dev/null
else
  echo "FATAL: vendor.img /etc/selinux not found"; exit 1
fi
fusermount -u /root/vm 2>/dev/null

cd /; umount $M; umount $S
e2fsck -f -n $IMG 2>&1 | tail -2
echo "image sha: $(sha256sum $IMG | cut -c1-24)"
echo STEP1_OK
