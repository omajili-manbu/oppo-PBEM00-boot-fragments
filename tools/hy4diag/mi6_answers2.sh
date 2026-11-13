#!/bin/bash
PKG='/mnt/e/work/oppo-pbem00-kernel/小米6_HyperOS 4.0.30.0.XPCCNXM_pudding_一键刷入'
C=/mnt/c/hy4work
mkdir -p $C

echo "########## 1. ALL partitions flashed via rawprogram (which file goes to vendor?) ##########"
for x in $PKG/images/rawprogram*.xml; do
  echo "--- $(basename $x) ---"
  grep -oE 'filename="[^"]*" label="[^"]*"' "$x" | grep -vE 'filename=""' | head -30
done

echo
echo "########## 2. HyperOS 3 W-OTA-8 zip contents ##########"
unzip -l "$PKG/zip/HyperOS 3 W-OTA-8 simplified.zip" | head -40

echo
echo "########## 3. init patch site: full PLT resolve ##########"
python3 - <<'PY'
import subprocess, re, struct
I = '/mnt/c/hy4work/init_ours'
# parse .rela.plt: r_offset -> symbol
out = subprocess.run(['aarch64-linux-gnu-readelf','-rW',I],capture_output=True,text=True).stdout
rel = {}
cur = None
for line in out.splitlines():
    if '.rela.plt' in line and "'RELA'" not in line:
        cur = 'plt'
        continue
    if cur:
        m = re.match(r'^([0-9a-f]{8,16})\s+([0-9a-f]+)\s+(\S+)\s+([0-9a-f]*)\s+(\S+)', line)
        if m:
            rel[int(m.group(1),16)] = m.group(5)
targets = [0x29dc08, 0x29fd38, 0x29f0a8, 0x29fd20, 0x29dcc8, 0x29fd20]
for t in [0x29dc08,0x29fd38,0x29f0a8,0x29fd20,0x29dcc8]:
    print(hex(t), '->', rel.get(t, 'NOT FOUND'))
PY

echo
echo "########## 4. disasm around patch site 0x11c740-0x11c7d0 ##########"
aarch64-linux-gnu-objdump -d --start-address=0x11c740 --stop-address=0x11c7d0 $C/init_ours 2>/dev/null | tail -n +7

echo
echo "########## 5. strings near 'Permissiver'-style flag ##########"
strings -a $C/init_ours | grep -aE 'vendor_sepolicy|plat_sepolicy_vers|Compiling SELinux|Opening SELinux|selinux_android_load|policyvers' | head -10
echo DONE2
