#!/bin/bash
cd /root
echo "=== all call sites of __dl_abort (0x64500) ==="
aarch64-linux-gnu-objdump -d linker64 > /root/lk.dis 2>/dev/null
grep -nE 'bl\s+64500 <__dl_abort>' /root/lk.dis | head -40

echo
echo "=== which functions contain those call sites ==="
python3 - <<'PY'
import re
lines=open('/root/lk.dis').read().splitlines()
# build address -> function name map from objdump labels
funcs=[]
for ln in lines:
    m=re.match(r'^([0-9a-f]+) <(.+)>:$', ln)
    if m: funcs.append((int(m.group(1),16), m.group(2)))
funcs.sort()
def owner(a):
    lo,hi=0,len(funcs)-1; best=None
    for addr,name in funcs:
        if addr<=a: best=(addr,name)
        else: break
    return best
calls=[]
for ln in lines:
    m=re.search(r'^\s+([0-9a-f]+):.*\bbl\s+64500 <__dl_abort>', ln)
    if m: calls.append(int(m.group(1),16))
print('call site count:', len(calls))
seen={}
for c in calls:
    o=owner(c)
    key=o[1] if o else '?'
    if key not in seen: seen[key]=[]
    seen[key].append(c)
for k,v in seen.items():
    print('  %-70s %d site(s): %s' % (k, len(v), ' '.join(hex(x) for x in v[:3])))
PY
echo DONE_CALLS
