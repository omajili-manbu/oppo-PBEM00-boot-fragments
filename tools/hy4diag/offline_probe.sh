#!/bin/bash
# Offline forensics: three boot ramdisks + merged system image structure
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
export DEBIAN_FRONTEND=noninteractive
for t in cpio lz4; do command -v $t >/dev/null 2>&1 || apt-get install -y $t >/dev/null 2>&1; done
echo "tools: $(command -v cpio) $(command -v lz4)"

echo "########## 1. FLASHED BOOT RAMDISK (bootable_337_C7_usbser) ##########"
cd $D/b1 || exit 1
echo "--- listing ---"
cpio -itv < ramdisk.cpio 2>&1 | head -100
echo "--- count: $(cpio -it < ramdisk.cpio 2>/dev/null | wc -l)"
rm -rf /tmp/rd1; mkdir -p /tmp/rd1; cd /tmp/rd1
cpio -idm --no-absolute-filenames < $D/b1/ramdisk.cpio 2>/dev/null
echo "--- extracted tree ---"
find . | head -60
echo "--- .backup/.magisk ---"
cat .backup/.magisk 2>/dev/null | head -20
echo "--- ./init type ---"
ls -la init 2>/dev/null
file init 2>/dev/null
echo "--- ./init strings (first 15 lines) ---"
strings -a init 2>/dev/null | head -15
echo "--- magisk binaries ---"
find . -name 'magisk*' -o -name '*.rc' | head -20

echo "########## 2. HYPEROS init_boot RAMDISK ##########"
cd $D/ib || exit 1
cpio -itv < ramdisk.cpio 2>&1 | head -100
echo "--- count: $(cpio -it < ramdisk.cpio 2>/dev/null | wc -l)"
rm -rf /tmp/rd2; mkdir -p /tmp/rd2; cd /tmp/rd2
cpio -idm --no-absolute-filenames < $D/ib/ramdisk.cpio 2>/dev/null
echo "--- extracted tree ---"
find . | head -60
echo "--- ./init ---"
ls -la init 2>/dev/null
file init 2>/dev/null
readelf -h init 2>/dev/null | grep -E 'Class|Machine|Type'
readelf -l init 2>/dev/null | grep -A1 -i interp
readelf -d init 2>/dev/null | grep -E 'NEEDED'
echo "--- strings hallmarks ---"
strings -a init 2>/dev/null | grep -E 'skip_initramfs|first stage|second stage|force_normal_boot|first_stage_ramdisk|Failed to read fstab|Init encountered errors|bootstrap|/fstab' | head -30

echo "########## 3. HYPEROS vendor_boot RAMDISK ##########"
cd $D/vb || exit 1
lz4 -d -c ramdisk.cpio > /tmp/vb_rd.cpio 2>/tmp/vb_err || cat /tmp/vb_err
ls -l /tmp/vb_rd.cpio
cpio -itv < /tmp/vb_rd.cpio 2>&1 | head -60
echo "--- count: $(cpio -it < /tmp/vb_rd.cpio 2>/dev/null | wc -l)"
echo "--- fstab-ish ---"
cpio -it < /tmp/vb_rd.cpio 2>/dev/null | grep -iE 'fstab|init\.|selinux' | head -20

echo "########## 4. MERGED SYSTEM IMAGE ##########"
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
M=/tmp/sysm
umount $M 2>/dev/null; mkdir -p $M
mount -o loop,ro $IMG $M || { echo MOUNT_FAIL; exit 1; }
echo "===== identity (system/build.prop) ====="
grep -E '^(ro.build.version.sdk|ro.build.version.release|ro.build.version.codename|ro.build.id|ro.product.device|ro.product.model|ro.product.name|ro.build.type|ro.build.tags|ro.zygote|ro.product.cpu.abilist|ro.apex.updatable|ro.vndk.version|ro.product.vndk.version|ro.hardware|ro.board.platform)=' $M/system/build.prop 2>/dev/null
echo "===== init / linker / libc ====="
ls -l $M/init $M/system/bin/init $M/system/bin/sh $M/system/bin/linker64 $M/system/lib64/libc.so $M/system/lib64/libm.so $M/system/lib64/libdl.so $M/system/lib64/libbase.so $M/system/lib64/liblog.so 2>&1
echo "===== file(1) ====="
file $M/system/bin/init $M/system/bin/linker64 $M/system/bin/sh 2>&1
echo "===== readelf /system/bin/init ====="
readelf -h $M/system/bin/init 2>&1 | grep -E 'Class|Machine|Type|Entry'
readelf -l $M/system/bin/init 2>&1 | grep -A1 -i interp
readelf -d $M/system/bin/init 2>&1 | grep -E 'NEEDED|FLAGS'
echo "===== init strings hallmarks ====="
strings -a $M/system/bin/init | grep -E 'skip_initramfs|first stage|second stage|force_normal_boot|first_stage_ramdisk|Failed to read fstab|Init encountered errors|bootstrap' | head -30
echo "===== apex dirs ====="
ls -l $M/system/apex/ | head -40
echo "--- /apex ---"; ls -la $M/apex 2>&1 | head
echo "--- /bootstrap-apex ---"; ls -la $M/bootstrap-apex 2>&1 | head
echo "===== fstab files ====="
find $M -maxdepth 4 -name 'fstab*' 2>/dev/null | head -20
echo "===== init rc ====="
ls -l $M/system/etc/init/hw/ 2>&1 | head -25
echo "--- root init.environ.rc ---"; cat $M/init.environ.rc 2>/dev/null | head -30
echo "===== selinux policy dirs ====="
ls $M/system/etc/selinux/ | head -30
echo "count=$(ls $M/system/etc/selinux/ | wc -l)  system_ext=$(ls $M/system_ext/etc/selinux/ 2>/dev/null | wc -l)"
echo "===== vendor/odm/product/mnt ====="
ls -la $M/vendor $M/odm $M/product $M/mnt 2>&1 | head -25
echo "===== dangling symlinks under system lib dirs ====="
python3 - "$M" <<'EOF'
import os, sys
M = sys.argv[1]
for sub in ('system/lib64','system/bin','system/lib','system_ext/lib64','mi_ext'):
    tot = bad = 0; samples = []
    base = os.path.join(M, sub)
    if not os.path.isdir(base): continue
    for root, dirs, files in os.walk(base):
        for n in files + dirs:
            p = os.path.join(root, n)
            if not os.path.islink(p): continue
            tot += 1
            t = os.readlink(p)
            real = os.path.join(M, t.lstrip('/')) if t.startswith('/') else os.path.join(os.path.dirname(p), t)
            if not os.path.exists(real):
                bad += 1
                if len(samples) < 8: samples.append((p[len(M):], t))
    print(f'{sub}: symlinks={tot} dangling={bad}')
    for s in samples: print('   DANGLING', s[0], '->', s[1])
EOF
umount $M
echo "########## DONE ##########"
