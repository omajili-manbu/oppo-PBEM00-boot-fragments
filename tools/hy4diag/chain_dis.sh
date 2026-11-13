#!/bin/bash
cd /root
python3 - <<'PY'
import re, subprocess
lines=open('/root/lk.dis').read().splitlines()
funcs=[]
for ln in lines:
    m=re.match(r'^([0-9a-f]+) <(.+)>:', ln)
    if m: funcs.append((int(m.group(1),16), m.group(2)))
funcs.sort()
def owner(a):
    best=None
    for addr,name in funcs:
        if addr<=a: best=(addr,name)
        else: break
    return best
targets=[0xf6c00,0xf6a44,0x7b430,0xf0b2c,0xf6a00,0xf6b00]
for t in targets:
    o=owner(t)
    print('off 0x%-8x -> %s  (func start 0x%x, +0x%x)' % (t, o[1][:90], o[0], t-o[0]))
PY

echo
echo "=== disasm around 0xf6a00 .. 0xf6c40 ==="
aarch64-linux-gnu-objdump -d --start-address=0xf6a00 --stop-address=0xf6c40 linker64 2>/dev/null | tail -n +7
echo
echo "=== disasm around 0xf0b00 .. 0xf0b60 ==="
aarch64-linux-gnu-objdump -d --start-address=0xf0b00 --stop-address=0xf0b60 linker64 2>/dev/null | tail -n +7
echo
echo "=== disasm around 0x7b420 .. 0x7b450 ==="
aarch64-linux-gnu-objdump -d --start-address=0x7b420 --stop-address=0x7b450 linker64 2>/dev/null | tail -n +7
echo DONE_CHAIN
