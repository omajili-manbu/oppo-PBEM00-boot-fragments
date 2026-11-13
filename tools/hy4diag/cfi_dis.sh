#!/bin/bash
cd /root
echo "=== CFIShadowWriter::MaybeInit address ==="
grep -nE '<__dl__ZN15CFIShadowWriter9MaybeInitE' /root/lk.dis | head -3
ADDR=$(grep -oE '^[0-9a-f]+ <__dl__ZN15CFIShadowWriter9MaybeInitE' /root/lk.dis | head -1 | awk '{print $1}')
echo "addr=$ADDR"
[ -z "$ADDR" ] && { echo "not found"; exit 1; }

echo
echo "=== disassembly: look for mmap flags / prctl / abort ==="
python3 - "$ADDR" <<'PY'
import sys,re
a=int(sys.argv[1],16)
lines=open('/root/lk.dis').read().splitlines()
start=None
for i,ln in enumerate(lines):
    m=re.match(r'^([0-9a-f]+) <(.+)>:', ln)
    if m and int(m.group(1),16)==a:
        start=i; break
print('---- first 120 instructions ----')
for ln in lines[start:start+120]:
    print(ln)
PY

echo
echo "=== interesting constants in whole function ==="
python3 - "$ADDR" <<'PY'
import sys,re
a=int(sys.argv[1],16)
lines=open('/root/lk.dis').read().splitlines()
start=None; end=None
for i,ln in enumerate(lines):
    m=re.match(r'^([0-9a-f]+) <(.+)>:', ln)
    if m and int(m.group(1),16)==a: start=i
    elif start is not None and m and int(m.group(1),16)>a: end=i; break
body=lines[start:end or start+400]
for ln in body:
    if re.search(r'#0x[0-9a-f]{4,}|MAP_|PR_SET_VMA|bl\s+\w+ <__dl_(mmap|prctl|abort|syscall)', ln):
        print(ln.strip())
PY
echo DONE_CFI
