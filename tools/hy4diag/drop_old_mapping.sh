#!/bin/bash
set -e
SYS=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
M=/mnt/sys
mountpoint -q $M || mount -o loop,rw $SYS $M || true
mountpoint -q $M && echo "system rw ok"

echo "=== before ==="
ls $M/system/etc/selinux/mapping/ | tr '\n' ' '; echo

echo "=== remove our extra 26-29 mappings (unused now, one has a bad inode) ==="
for v in 26.0 27.0 28.0 29.0; do
  rm -f $M/system/etc/selinux/mapping/$v.cil
done
echo "=== after ==="
ls $M/system/etc/selinux/mapping/ | tr '\n' ' '; echo

sync
cd /; umount $M
echo "=== fsck: bad inode should be gone ==="
e2fsck -fy $SYS 2>&1 | tail -6
echo "system sha: $(sha256sum $SYS | cut -c1-24)"
echo CLEANUP_DONE
