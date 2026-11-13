#!/bin/bash
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
M=/tmp/sysm
mkdir -p $M
mountpoint -q $M || mount -o loop,ro $IMG $M || { echo MOUNTFAIL; exit 1; }
echo "===== bootstrap linker exists? ====="
ls -la $M/system/bin/bootstrap/ 2>&1 | head -10
ls -la $M/system/lib64/bootstrap/ 2>&1 | head -20
echo "===== ld.config files ====="
ls -l $M/system/etc/ | grep -i -E 'ld\.config|linker' 2>&1 | head
echo "===== init strings: bootstrap / apexd ====="
strings -a $M/system/bin/init | grep -iE 'bootstrap-apex|bootstrap_apex|apexd|/apex/' | head -25
echo "===== init strings: fstab/mount ====="
strings -a $M/system/bin/init | grep -iE 'first_stage|fstab|force_normal_boot|skip_initramfs|mount point|Could not mount' | head -40
echo "===== props ====="
grep -E '^(ro.build.flavor|ro.system.build.version.sdk|ro.apex.updatable|ro.boot.dynamic_partitions|ro.virtual_ab|ro.crypto.state|ro.build.system_root_image|ro.treble.enabled|ro.vndk.version)' $M/system/build.prop $M/system_ext/build.prop 2>/dev/null | head
echo "===== system/etc/ramdisk ====="
ls -l $M/system/etc/ramdisk/ 2>&1 | head -5
echo "===== how many dangling symlinks in image root level ====="
python3 - "$M" <<'PYEOF'
import os,sys
M=sys.argv[1]
bad=0;samples=[]
for n in sorted(os.listdir(M)):
    p=os.path.join(M,n)
    if os.path.islink(p):
        t=os.readlink(p)
        real=os.path.join(M,t.lstrip('/'))
        if not os.path.exists(real):
            bad+=1; samples.append((n,t))
print('root symlinks dangling:',bad)
for s in samples: print('  ',s[0],'->',s[1])
PYEOF
umount $M
echo "===== vendor.img selinux via erofsfuse ====="
V=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/vendor.img
rm -rf /tmp/vv && mkdir -p /tmp/vv
erofsfuse $V /tmp/vv 2>/dev/null && sleep 1
ls /tmp/vv/etc/selinux/ 2>&1 | head -20
echo "count=$(ls /tmp/vv/etc/selinux/ 2>/dev/null | wc -l)"
echo "--- precompiled_sepolicy size ---"
ls -l /tmp/vv/etc/selinux/precompiled_sepolicy 2>&1
fusermount -u /tmp/vv 2>/dev/null
echo DONE3B
