#!/bin/bash
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
PKG='/mnt/e/work/oppo-pbem00-kernel/小米6_HyperOS 4.0.30.0.XPCCNXM_pudding_一键刷入'

echo "########## 0. raw system image still there? ##########"
ls -l /mnt/e/hy4tmp/system.raw 2>/dev/null || echo "system.raw GONE - will reconvert to C:"
C=/mnt/c/hy4work
mkdir -p $C

if [ ! -f /mnt/e/hy4tmp/system.raw ]; then
  echo "--- converting sparse to raw on C: ---"
  simg2img "$PKG/images/system.img" $C/system.raw && echo CONV_OK
  ls -l $C/system.raw
fi
RAW=$(ls /mnt/e/hy4tmp/system.raw $C/system.raw 2>/dev/null | head -1)
echo "RAW=$RAW"

echo
echo "########## 1. mount mi6 system ##########"
mkdir -p /mnt/m6
mountpoint -q /mnt/m6 || mount -o loop,ro "$RAW" /mnt/m6
mountpoint -q /mnt/m6 && echo "mi6 system mounted"
mkdir -p /mnt/ou
mountpoint -q /mnt/ou || mount -o loop,ro /mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img /mnt/ou
mountpoint -q /mnt/ou && echo "our system mounted"

echo
echo "########## 2. libselinux.so identical? (did THEY patch it?) ##########"
md5sum /mnt/m6/system/lib64/libselinux.so /mnt/ou/system/lib64/libselinux.so
echo "--- security_load_policy first 16 bytes (mi6 vs ours) ---"
od -A x -t x4 -j $((0x12fc4)) -N 16 /mnt/m6/system/lib64/libselinux.so
od -A x -t x4 -j $((0x12fc4)) -N 16 /mnt/ou/system/lib64/libselinux.so

echo
echo "########## 3. mapping dir: do they have 26-29? ##########"
echo "--- mi6 mapping ---"
ls /mnt/m6/system/etc/selinux/mapping/ 2>/dev/null | tr '\n' ' '; echo
echo "--- our mapping ---"
ls /mnt/ou/system/etc/selinux/mapping/ | tr '\n' ' '; echo

echo
echo "########## 4. secilc / precompiled present in mi6? ##########"
ls -l /mnt/m6/system/bin/secilc 2>/dev/null || echo "no /system/bin/secilc"
find /mnt/m6 -maxdepth 4 -name 'secilc*' 2>/dev/null | head -3
ls /mnt/m6/vendor 2>/dev/null | wc -l
echo "--- mi6 vendor dir contents ---"
ls -la /mnt/m6/vendor 2>/dev/null | head -5

echo
echo "########## 5. mi6 init: patch context disasm with PLT resolve ##########"
cp /mnt/m6/system/bin/init $C/init_mi6
cp /mnt/ou/system/bin/init $C/init_ours
cmp -l $C/init_ours $C/init_mi6 | head -3
echo "--- .rela.plt entries at 0x29dc08/0x29fd38/0x29dc08/0x29f0a8/0x29fd20 ---"
for a in 29dc08 29fd38 29f0a8 29fd20 29dcc8; do
  echo "--- GOT $a ---"
  aarch64-linux-gnu-readelf -rW $C/init_ours 2>/dev/null | grep -i "0029fd38\|0029dc08\|0029f0a8\|0029fd20\|0029dcc8" | head -1
  aarch64-linux-gnu-readelf -rW $C/init_ours 2>/dev/null | grep -iE "^\S*\s+$a\s" | head -1
done
echo "--- raw rela.plt rows containing 29fd / 29dc ---"
aarch64-linux-gnu-readelf -rW $C/init_ours 2>/dev/null | grep -E '0029fd|0029dc|0029f0' | head -12
umount /mnt/m6 /mnt/ou 2>/dev/null
echo DONE_MI6_CHECK
