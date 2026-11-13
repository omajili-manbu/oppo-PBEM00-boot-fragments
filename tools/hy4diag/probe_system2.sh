#!/bin/bash
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
M=/tmp/sysm
umount $M 2>/dev/null; mkdir -p $M
mount -o loop,ro $IMG $M || { echo MOUNT_FAIL; exit 1; }
echo "===== identity ====="
grep -E '^(ro.build.version.sdk|ro.build.version.release|ro.build.id|ro.product.device|ro.product.model|ro.product.name|ro.build.type|ro.build.tags|ro.zygote|ro.product.cpu.abilist|ro.apex.updatable|ro.vndk.version|ro.product.vndk.version|ro.hardware|ro.board.platform)=' $M/system/build.prop 2>/dev/null
echo "===== init / linker / libc ====="
ls -l $M/init $M/system/bin/init $M/system/bin/sh $M/system/bin/linker64 $M/system/lib64/libc.so $M/system/lib64/libm.so $M/system/lib64/libdl.so $M/system/lib64/libbase.so $M/system/lib64/liblog.so 2>&1
echo "===== file(1) ====="
file $M/system/bin/init $M/system/bin/linker64 $M/system/bin/sh $M/system/bin/toybox 2>&1
echo "===== readelf /system/bin/init ====="
readelf -h $M/system/bin/init 2>&1 | grep -E 'Class|Machine|Type'
readelf -l $M/system/bin/init 2>&1 | grep -A1 -i interp
readelf -d $M/system/bin/init 2>&1 | grep -E 'NEEDED|FLAGS'
echo "===== apex dirs ====="
ls $M/system/apex/ | head -40
echo "--- count: $(ls $M/system/apex/ | wc -l)"
echo "--- /apex root ---"; ls -la $M/apex 2>&1 | head
echo "--- /bootstrap-apex ---"; ls -la $M/bootstrap-apex 2>&1 | head
echo "--- /linkerconfig ---"; ls -la $M/linkerconfig 2>&1 | head
echo "--- /second_stage_resources ---"; ls -la $M/second_stage_resources 2>&1 | head
echo "--- /debug_ramdisk ---"; ls -la $M/debug_ramdisk 2>&1 | head
echo "===== fstab files ====="
find $M -maxdepth 4 -name 'fstab*' 2>/dev/null | head -20
echo "===== init rc ====="
ls -l $M/system/etc/init/hw/ 2>&1 | head -25
echo "--- root init.environ.rc ---"; cat $M/init.environ.rc 2>/dev/null
echo "===== selinux dirs ====="
echo "system: $(ls $M/system/etc/selinux/ | wc -l) files"; ls $M/system/etc/selinux/ | head -8
echo "system_ext: $(ls $M/system_ext/etc/selinux/ 2>/dev/null | wc -l) files"
echo "===== vendor/odm/product/mnt ====="
ls -la $M/vendor $M/odm $M/product $M/mnt 2>&1 | head -25
echo "===== symlink audit (system lib/bin, system_ext, mi_ext) ====="
python3 - "$M" <<'PYEOF'
import os, sys
M = sys.argv[1]
for sub in ('system/lib64','system/bin','system/lib','system_ext/lib64','system_ext/bin','mi_ext'):
    tot = bad = 0; samples = []
    base = os.path.join(M, sub)
    if not os.path.isdir(base):
        print(sub, 'MISSING'); continue
    for root, dirs, files in os.walk(base):
        for n in files + dirs:
            p = os.path.join(root, n)
            if not os.path.islink(p): continue
            tot += 1
            t = os.readlink(p)
            real = os.path.join(M, t.lstrip('/')) if t.startswith('/') else os.path.join(os.path.dirname(p), t)
            if not os.path.exists(real):
                bad += 1
                if len(samples) < 10: samples.append((p[len(M):], t))
    print(f'{sub}: symlinks={tot} dangling={bad}')
    for s in samples: print('   DANGLING', s[0], '->', s[1])
PYEOF
echo "===== quick look: does /system/bin/init's needed libs resolve? ====="
python3 - "$M" <<'PYEOF'
import os, subprocess, sys
M = sys.argv[1]
init = M + '/system/bin/init'
out = subprocess.run(['readelf','-d',init], capture_output=True, text=True).stdout
needed = [l.split('[')[1].rstrip(']') for l in out.splitlines() if 'NEEDED' in l]
print('NEEDED:', needed)
for n in needed:
    found = []
    for d in ('/system/lib64','/system_ext/lib64','/system/lib','/mi_ext/lib64'):
        p = M + d + '/' + n
        if os.path.lexists(p):
            if os.path.islink(p):
                t = os.readlink(p)
                real = os.path.join(M, t.lstrip('/')) if t.startswith('/') else os.path.join(os.path.dirname(p), t)
                found.append(f'{d}/{n} -> {t} [{"OK" if os.path.exists(real) else "DANGLING"}]')
            else:
                found.append(f'{d}/{n} [real]')
            break
    else:
        found.append('NOT FOUND')
    print(' ', n, found[0])
PYEOF
umount $M
echo "===== vendor_boot fstab.qcom (source device reference) ====="
sed -n '1,60p' /tmp/vb_rd.cpio >/dev/null 2>&1
rm -rf /tmp/vbf && mkdir -p /tmp/vbf && cd /tmp/vbf
cpio -idm --no-absolute-filenames 'first_stage_ramdisk/fstab.qcom' < /tmp/vb_rd.cpio 2>/dev/null
grep -vE '^\s*#|^\s*$' first_stage_ramdisk/fstab.qcom | head -30
echo "===== init_boot ramdisk build.prop ====="
rm -rf /tmp/ibf && mkdir -p /tmp/ibf && cd /tmp/ibf
cpio -idm --no-absolute-filenames 'system/etc/ramdisk/build.prop' < /mnt/e/work/oppo-pbem00-kernel/tools/hy4diag/ib/ramdisk.cpio 2>/dev/null
cat system/etc/ramdisk/build.prop 2>/dev/null
echo "DONE2"
