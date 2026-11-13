#!/bin/bash
M=/tmp/sysm
mkdir -p $M
mountpoint -q $M || mount -o loop,ro /mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img $M
echo "===== init NEEDED resolution ====="
python3 - "$M" <<'PYEOF'
import os, subprocess, sys
M=sys.argv[1]
out=subprocess.run(['readelf','-d',M+'/system/bin/init'],capture_output=True,text=True).stdout
needed=[l.split('[')[1].rstrip(']') for l in out.splitlines() if 'NEEDED' in l]
dirs=('system/lib64','system/lib64/bootstrap','system_ext/lib64','mi_ext/lib64','system/lib')
for n in needed:
    res=None
    for d in dirs:
        p=os.path.join(M,d,n)
        if os.path.lexists(p):
            if os.path.islink(p):
                t=os.readlink(p); real=os.path.join(M,t.lstrip('/'))
                res=f'{d}/{n} -> {t} [{"OK" if os.path.exists(real) else "DANGLING"}]'
            else:
                res=f'{d}/{n} [real {os.path.getsize(p)}]'
            break
    print(f'{n:32s} {res or "*** NOT FOUND in system/lib64 ***"}')
PYEOF
umount $M
echo "===== kernel tree ====="
ls /home/qwe12/oppo-pbem00-kernel 2>&1 | head -20
echo "--- find policydb.c ---"
find /home/qwe12/oppo-pbem00-kernel -maxdepth 6 -name 'policydb.c' 2>/dev/null | head -3
echo DONE4
