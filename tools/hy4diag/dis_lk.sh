#!/bin/bash
M=/mnt/chk
mkdir -p $M
mountpoint -q $M || mount -o loop,ro /mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img $M
L=$M/system/bin/bootstrap/linker64
cp $L /root/linker64
echo "=== segments (find p_offset=0x50000) ==="
readelf -lW /root/linker64 2>/dev/null | awk 'NR>5 && $1=="LOAD" {print}' | head -6

echo
echo "=== compute vaddr for file offset 0x645a0 ==="
python3 - <<'PY'
import subprocess, re
out = subprocess.run(['aarch64-linux-gnu-readelf','-lW','/root/linker64'],capture_output=True,text=True).stdout
segs=[]
for line in out.splitlines():
    p=line.split()
    if p and p[0]=='LOAD':
        off=int(p[1],16); va=int(p[2],16); filesz=int(p[4],16); memsz=int(p[5],16); fl=p[6]
        segs.append((off,va,filesz,fl))
print('segments:', [(hex(o),hex(v),hex(f),fl) for o,v,f,fl in segs])
target=0x645a0
for off,va,filesz,fl in segs:
    if off <= target < off+filesz:
        print('file_off 0x%x -> vaddr 0x%x  (flags %s)' % (target, va + (target-off), fl))
PY

echo
echo "=== disassembly around the abort (ours = unpatched) ==="
V=$(python3 - <<'PY'
import subprocess
out = subprocess.run(['aarch64-linux-gnu-readelf','-lW','/root/linker64'],capture_output=True,text=True).stdout
for line in out.splitlines():
    p=line.split()
    if p and p[0]=='LOAD':
        off=int(p[1],16); va=int(p[2],16); filesz=int(p[4],16)
        if off <= 0x645a0 < off+filesz:
            print(hex(va + (0x645a0-off))); break
PY
)
echo "vaddr=$V"
python3 - "$V" <<'PY'
import sys, subprocess
v=int(sys.argv[1],16)
start=v-0x100; stop=v+0x60
out=subprocess.run(['aarch64-linux-gnu-objdump','-d',
                    '--start-address=%d'%start,'--stop-address=%d'%stop,
                    '/root/linker64'],capture_output=True,text=True).stdout
print(out[-6000:])
PY
umount $M 2>/dev/null
echo DONE_LK
