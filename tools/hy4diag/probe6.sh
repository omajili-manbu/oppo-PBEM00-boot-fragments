#!/bin/bash
M=/tmp/sysm
mkdir -p $M
mountpoint -q $M || mount -o loop,ro /mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img $M
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
echo "=== kernel supported selinux classes (4.9) ==="
python3 - "$K/security/selinux/include/classmap.h" <<'PY'
import re,sys
s=open(sys.argv[1]).read()
# classmap entries look like: { "file", ... }
names=re.findall(r'\{\s*"([a-z_0-9]+)"', s)
print(len(names), sorted(set(names)))
PY
echo "=== policy classes referenced in HyperOS plat_sepolicy.cil ==="
python3 - "$M/system/etc/selinux/plat_sepolicy.cil" <<'PY'
import re,sys
s=open(sys.argv[1],errors='replace').read()
cls=sorted(set(re.findall(r'\(class ([a-z_0-9]+)', s)))
print(len(cls), cls)
PY
echo "=== new-feature classes present? ==="
for c in bpf io_uring perfmon xdp mptcp binder_inode perf_event rdma_cm cap_userns; do
  n=$(grep -c "(class $c" $M/system/etc/selinux/plat_sepolicy.cil 2>/dev/null)
  echo "class $c: $n"
done
echo "=== policy vers hints ==="
cat $M/system_ext/etc/selinux/*vers*.txt 2>/dev/null | head -3
ls $M/system/etc/selinux/ | head -20
umount $M
echo DONE6
